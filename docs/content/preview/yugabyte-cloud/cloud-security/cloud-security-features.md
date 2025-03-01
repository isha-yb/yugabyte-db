---
title: Security architecture
linkTitle: Security architecture
description: Security architecture of YugabyteDB Managed.
image: /images/section_icons/index/secure.png
menu:
  preview:
    parent: cloud-security
    identifier: cloud-security-features
weight: 10
isTocNested: true
showAsideToc: true
---

YugabyteDB Managed is a fully managed YugabyteDB-as-a-Service that allows you to run YugabyteDB clusters on public cloud providers such as Google Cloud Platform (GCP) and Amazon Web Services (AWS), with more public cloud provider options coming soon. YugabyteDB Managed runs on top of [YugabyteDB Anywhere](../../../yugabyte-platform/overview/). It is responsible for creating and managing customer YugabyteDB clusters deployed on cloud provider infrastructure.

![YugabyteDB Managed high-level architecture](/images/yb-cloud/cloud-security-diagram.png)

All customer clusters are firewalled from each other. Outside connections are also firewalled according to the [IP allow list](../../cloud-secure-clusters/add-connections/) rules that you assign to your clusters. You can also connect Dedicated (that is, not Sandbox) clusters to virtual private clouds (VPCs) on the public cloud provider of your choice (subject to the IP allow list rules).

## Infrastructure security

YugabyteDB Managed uses both encryption in transit and encryption at rest to protect clusters and cloud infrastructure.

All communication between YugabyteDB Managed architecture domains is encrypted in transit using TLS. Likewise, all communication between clients or applications and clusters is encrypted in transit. Every cluster has its own certificates, generated when the cluster is created and signed by the Yugabyte internal PKI. Root and intermediate certificates are not extractable from the hardware security appliances.

Data at rest, including clusters and backups, is AES-256 encrypted using native cloud provider technologies - S3 and EBS volume encryption for AWS, and server-side and persistent disk encryption for GCP. Encryption keys are managed by the cloud provider and anchored by hardware security appliances. Customers can enable [column-level encryption](../../../secure/column-level-encryption/) as an additional security control.

YugabyteDB Managed provides DDoS and application layer protection, and automatically blocks network protocol and volumetric DDoS attacks.

## Securing database clusters by default

Yugabyte secures YugabyteDB Managed databases using the same default [security measures that we recommend to our customers](../../../secure/security-checklist/) to secure their own YugabyteDB installations, including:

- authentication
- role-based access control
- dedicated users
- limited network exposure
- encryption in transit
- encryption at rest

## Data privacy and compliance

For information on data privacy and compliance, refer to the [Yugabyte DPA](https://www.yugabyte.com/yugabyte-cloud-data-processing-addendum/).

## Auditing

Yugabyte supports audit logging at the account and database level.

For information on database audit logging, refer to [Configure Audit Logging](../../../secure/audit-logging/audit-logging-ysql/).
