package com.yugabyte.yw.commissioner.tasks;

import java.util.Collection;
import java.util.UUID;

import com.google.inject.Inject;
import com.yugabyte.yw.commissioner.BaseTaskDependencies;
import com.yugabyte.yw.commissioner.TaskExecutor.SubTaskGroup;
import com.yugabyte.yw.commissioner.UserTaskDetails;
import com.yugabyte.yw.commissioner.tasks.params.NodeAccessTaskParams;
import com.yugabyte.yw.commissioner.tasks.params.RotateAccessKeyParams;
import com.yugabyte.yw.commissioner.tasks.subtasks.AddAuthorizedKey;
import com.yugabyte.yw.commissioner.tasks.subtasks.NodeTaskBase;
import com.yugabyte.yw.commissioner.tasks.subtasks.RemoveAuthorizedKey;
import com.yugabyte.yw.commissioner.tasks.subtasks.UpdateUniverseAccessKey;
import com.yugabyte.yw.commissioner.tasks.subtasks.VerifyNodeSSHAccess;
import com.yugabyte.yw.common.NodeManager;
import com.yugabyte.yw.common.Util;
import com.yugabyte.yw.forms.UniverseDefinitionTaskParams.Cluster;
import com.yugabyte.yw.models.AccessKey;
import com.yugabyte.yw.models.Provider;
import com.yugabyte.yw.models.Universe;
import com.yugabyte.yw.models.helpers.NodeDetails;
import com.yugabyte.yw.commissioner.ITask.Retryable;

import lombok.extern.slf4j.Slf4j;

@Slf4j
@Retryable
public class RotateAccessKey extends UniverseTaskBase {

  @Inject NodeManager nodeManager;

  @Inject
  protected RotateAccessKey(BaseTaskDependencies baseTaskDependencies) {
    super(baseTaskDependencies);
  }

  protected RotateAccessKeyParams taskParams() {
    return (RotateAccessKeyParams) taskParams;
  }

  @Override
  public void run() {
    log.info("Running {}", getName());
    UUID customerUUID = taskParams().customerUUID;
    UUID universeUUID = taskParams().universeUUID;
    UUID providerUUID = taskParams().providerUUID;
    AccessKey newAccessKey = taskParams().newAccessKey;
    Provider provider = Provider.getOrBadRequest(customerUUID, providerUUID);
    String customSSHUser = Util.DEFAULT_YB_SSH_USER;
    Universe universe = Universe.getOrBadRequest(universeUUID);
    checkPausedOrNonLiveNodes(universe, newAccessKey);
    try {
      lockUniverse(-1);
      // create check connection with current keys and create add key task
      UserTaskDetails.SubTaskGroupType subtaskGroupType =
          UserTaskDetails.SubTaskGroupType.RotateAccessKey;
      for (Cluster cluster : universe.getUniverseDetails().clusters) {
        AccessKey clusterAccessKey =
            AccessKey.getOrBadRequest(providerUUID, cluster.userIntent.accessKeyCode);
        String sudoSSHUser = clusterAccessKey.getKeyInfo().sshUser;
        if (sudoSSHUser == null) {
          sudoSSHUser = provider.sshUser != null ? provider.sshUser : Util.DEFAULT_SUDO_SSH_USER;
        }
        Collection<NodeDetails> clusterNodes = universe.getNodesInCluster(cluster.uuid);
        // verify connection to yugabyte user
        createNodeAccessTasks(
                clusterNodes,
                clusterAccessKey,
                customerUUID,
                providerUUID,
                universeUUID,
                newAccessKey,
                "VerifyNodeSSHAccess",
                customSSHUser)
            .setSubTaskGroupType(subtaskGroupType);
        // verify conenction to sudo user
        createNodeAccessTasks(
                clusterNodes,
                clusterAccessKey,
                customerUUID,
                providerUUID,
                universeUUID,
                newAccessKey,
                "VerifyNodeSSHAccess",
                sudoSSHUser)
            .setSubTaskGroupType(subtaskGroupType);
        // add key to yugabyte user
        createNodeAccessTasks(
                clusterNodes,
                clusterAccessKey,
                customerUUID,
                providerUUID,
                universeUUID,
                newAccessKey,
                "AddAuthorizedKey",
                customSSHUser)
            .setSubTaskGroupType(subtaskGroupType);
        // add key to sudo user
        createNodeAccessTasks(
                clusterNodes,
                clusterAccessKey,
                customerUUID,
                providerUUID,
                universeUUID,
                newAccessKey,
                "AddAuthorizedKey",
                sudoSSHUser)
            .setSubTaskGroupType(subtaskGroupType);
        // remove key from sudo user
        createNodeAccessTasks(
                clusterNodes,
                newAccessKey,
                customerUUID,
                providerUUID,
                universeUUID,
                clusterAccessKey,
                "RemoveAuthorizedKey",
                sudoSSHUser)
            .setSubTaskGroupType(subtaskGroupType);
        // remove key from yugabte user
        createNodeAccessTasks(
                clusterNodes,
                newAccessKey,
                customerUUID,
                providerUUID,
                universeUUID,
                clusterAccessKey,
                "RemoveAuthorizedKey",
                customSSHUser)
            .setSubTaskGroupType(subtaskGroupType);
        createUpdateUniverseAccessKeyTask(universeUUID, cluster.uuid, newAccessKey.getKeyCode())
            .setSubTaskGroupType(subtaskGroupType);
      }
      getRunnableTask().runSubTasks();
    } catch (Exception e) {
      log.error(
          "Access Key Rotation failed for universe: {} with uuid {}",
          universe.name,
          universe.universeUUID);
      throw new RuntimeException(e);
    } finally {
      unlockUniverseForUpdate();
    }
    log.info("Successfully ran {}", getName());
  }

  public SubTaskGroup createNodeAccessTasks(
      Collection<NodeDetails> nodes,
      AccessKey accessKey,
      UUID customerUUID,
      UUID providerUUID,
      UUID universeUUID,
      AccessKey taskAccessKey,
      String command,
      String sshUser) {
    SubTaskGroup subTaskGroup = getTaskExecutor().createSubTaskGroup(command, executor);
    for (NodeDetails node : nodes) {
      NodeAccessTaskParams params =
          new NodeAccessTaskParams(
              customerUUID, providerUUID, node.azUuid, universeUUID, accessKey, sshUser);
      params.regionUUID = params.getRegion().uuid;
      params.nodeName = node.nodeName;
      params.taskAccessKey = taskAccessKey;
      NodeTaskBase task;
      if (command == "AddAuthorizedKey") {
        task = (AddAuthorizedKey) createTask(AddAuthorizedKey.class);
      } else if (command == "RemoveAuthorizedKey") {
        task = (RemoveAuthorizedKey) createTask(RemoveAuthorizedKey.class);
      } else {
        task = (VerifyNodeSSHAccess) createTask(VerifyNodeSSHAccess.class);
      }
      task.initialize(params);
      task.setUserTaskUUID(userTaskUUID);
      subTaskGroup.addSubTask(task);
    }
    getRunnableTask().addSubTaskGroup(subTaskGroup);
    return subTaskGroup;
  }

  public SubTaskGroup createUpdateUniverseAccessKeyTask(
      UUID universeUUID, UUID clusterUUID, String newAccessKeyCode) {
    SubTaskGroup subTaskGroup =
        getTaskExecutor().createSubTaskGroup("UpdateUniverseAccessKey", executor);

    UpdateUniverseAccessKey.Params params = new UpdateUniverseAccessKey.Params();
    params.newAccessKeyCode = newAccessKeyCode;
    params.universeUUID = universeUUID;
    params.clusterUUID = clusterUUID;
    UpdateUniverseAccessKey task = createTask(UpdateUniverseAccessKey.class);
    task.initialize(params);
    task.setUserTaskUUID(userTaskUUID);
    subTaskGroup.addSubTask(task);
    getRunnableTask().addSubTaskGroup(subTaskGroup);
    return subTaskGroup;
  }

  private void checkPausedOrNonLiveNodes(Universe universe, AccessKey newAccessKey) {
    if (universe.getUniverseDetails().universePaused) {
      throw new RuntimeException(
          "The universe "
              + universe.name
              + " is paused,"
              + " cannot run access key rotation. Retry with access key "
              + newAccessKey.getKeyCode()
              + " after resuming it!");
    } else if (!universe.allNodesLive()) {
      throw new RuntimeException(
          "The universe "
              + universe.name
              + " has non-live nodes,"
              + " cannot run access key rotation. Retry with access key "
              + newAccessKey.getKeyCode()
              + " after fixing node status!");
    }
  }
}
