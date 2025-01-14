// Copyright (c) YugaByte, Inc.

package com.yugabyte.yw.common.supportbundle;

import static com.yugabyte.yw.common.TestHelper.createTempFile;
import static org.junit.Assert.assertTrue;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.any;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import com.typesafe.config.Config;
import com.yugabyte.yw.common.FakeDBApplication;
import com.yugabyte.yw.common.ModelFactory;
import com.yugabyte.yw.common.SupportBundleUtil;
import com.yugabyte.yw.common.NodeUniverseManager;
import com.yugabyte.yw.controllers.handlers.UniverseInfoHandler;
import com.yugabyte.yw.forms.UniverseDefinitionTaskParams;
import com.yugabyte.yw.models.Customer;
import com.yugabyte.yw.models.helpers.NodeDetails;
import com.yugabyte.yw.models.Universe;
import java.io.File;
import java.io.IOException;
import java.nio.file.Paths;
import java.util.Date;
import java.util.HashSet;
import java.util.Arrays;
import java.text.ParseException;
import org.apache.commons.io.FileUtils;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.Mock;
import org.mockito.junit.MockitoJUnitRunner;

@RunWith(MockitoJUnitRunner.class)
public class TabletMetaComponentTest extends FakeDBApplication {
  @Mock public UniverseInfoHandler mockUniverseInfoHandler;
  @Mock public NodeUniverseManager mockNodeUniverseManager;
  @Mock public Config mockConfig;

  private Universe universe;
  private Customer customer;
  @Mock public SupportBundleUtil mockSupportBundleUtil = new SupportBundleUtil();
  private String fakeSupportBundleBasePath = "/tmp/yugaware_tests/support_bundle-tablet_meta/";
  private String fakeSourceComponentPath = fakeSupportBundleBasePath + "yb-data/";
  private String fakeBundlePath =
      fakeSupportBundleBasePath + "yb-support-bundle-test-20220308000000.000-logs";

  @Before
  public void setUp() throws IOException, ParseException {
    // Setup fake temp files, universe, customer
    this.customer = ModelFactory.testCustomer();
    this.universe = ModelFactory.createUniverse(customer.getCustomerId());

    // Add a fake node to the universe with a node name
    NodeDetails node = new NodeDetails();
    node.nodeName = "u-n1";
    this.universe =
        Universe.saveDetails(
            universe.universeUUID,
            (universe) -> {
              UniverseDefinitionTaskParams universeDetails = universe.getUniverseDetails();
              universeDetails.nodeDetailsSet = new HashSet<>(Arrays.asList(node));
              universe.setUniverseDetails(universeDetails);
            });

    // Create fake temp files to "download"
    createTempFile(
        fakeSourceComponentPath + "master/tablet-meta/", "tmp.txt", "test-tablet-meta-content");
    createTempFile(
        fakeSourceComponentPath + "tserver/tablet-meta/", "tmp.txt", "test-tablet-meta-content");

    // Mock all the invocations with fake data
    when(mockSupportBundleUtil.getDataDirPath(any(), any(), any(), any()))
        .thenReturn(fakeSupportBundleBasePath);

    when(mockUniverseInfoHandler.downloadNodeFile(any(), any(), any(), any(), any(), any()))
        .thenReturn(null);
  }

  @After
  public void tearDown() throws IOException {
    FileUtils.deleteDirectory(new File(fakeSupportBundleBasePath));
  }

  @Test
  public void testDownloadComponentBetweenDates() throws IOException, ParseException {
    // Define any start and end dates to filter - doesn't matter as internally not used
    Date startDate = new Date();
    Date endDate = new Date();

    // Calling the download function
    TabletMetaComponent tabletMetaComponent =
        new TabletMetaComponent(
            mockUniverseInfoHandler, mockNodeUniverseManager, mockConfig, mockSupportBundleUtil);
    tabletMetaComponent.downloadComponentBetweenDates(
        customer, universe, Paths.get(fakeBundlePath), startDate, endDate);

    // Check that the download function is called
    verify(mockUniverseInfoHandler, times(1))
        .downloadNodeFile(any(), any(), any(), any(), any(), any());

    // Check if the tablet_meta directory is created
    Boolean isDestDirCreated = new File(fakeBundlePath + "/tablet_meta").exists();
    assertTrue(isDestDirCreated);
  }
}
