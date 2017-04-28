RDS
===

These instructions will create a single MySQL RDS instance, suitable for use with `edxapp` or `edxanalytics` instances.

1. Navigate to the RDS Dashboard from you AWS console.
1. Go to `Instances` and click the `Launch DB Instance` button to create a new instance.
1. Choose `MySQL` from the Engine Selection list.
1. In the next step do NOT choose Multi-AZ and Provisioned IOPS Storage, unless you know you need those.

On the following pages, make the settings given below.  Everything that's not listed can be left at the default value.

Setting name                   | value
-------------------------------|----------------------------------
DB engine version              | 5.6.x (pick the latest version)
DB Instance Class              | `db.m3.medium`, or `db.t2.medium`
Multi-AZ Deployment            | No
Storage Type                   | General Purpose (SSD)
Allocated Storage              | 5 GB
DB Instance Identifier         | arbitrary, e.g. `edxapp` or `edxanalytics`
Master Username/Password       | arbitrary, note in secure repo.
Publicly Accessible            | No
VPC Security Group(s)          | `default` (VPC)
Database Name                  | **leave empty**
Backup Retention Period        | 14 days
Auto Minor Version Upgrade     | No

By leaving the `Database Name` field empty, no initial database will be created. We'll create the databases below.

Click the `Launch DB Instance` button once everything is set.

Once the RDS instance is set up, it should be accessible from the EC2 instance.
Test this by shelling into each EC2 instance and typing the following, using
the RDS endpoint host name:

    telnet xxxxxxxxx.rds.amazonaws.com 3306

Confirm that you see a "Connected to ..." message. Type Ctrl-D to exit the
telnet shell.
