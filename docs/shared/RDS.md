RDS
===

These instructions will create a single MySQL RDS instance, suitable for use with `edxapp` or `edxanalytics` instances.

Create
------

* Navigate to the RDS Dashboard from you AWS console.
* Go to `Instances` and click the `Launch DB Instance` button to create a new instance.
* Choose `MySQL` from the Engine Selection list.

On the following pages, make the settings given below.  Everything that's not listed can be left at the default value.

Setting name                   | Value                                      | Comments
-------------------------------|--------------------------------------------|--------------
DB engine version              | 5.6.x (pick the latest version)            |
DB Instance Class              | `db.m3.medium`, or `db.t2.medium`          |
Multi-AZ Deployment            | No                                         | Choose "Yes" only if you know you need these.
Provisioned IOPS Storage       | No                                         | Choose "Yes" only if you know you need these.
Storage Type                   | General Purpose (SSD)                      |
Allocated Storage              | 5 GB                                       |
DB Instance Identifier         | arbitrary, e.g. `edxapp` or `edxanalytics` |
Master Username/Password       | arbitrary, note in secure repo.            |
Publicly Accessible            | No                                         |
VPC Security Group(s)          | `default` (VPC)                            |
Database Name                  | **leave empty**                            | Create databases and users via mysql shell
Backup Retention Period        | 14 days                                    |
Auto Minor Version Upgrade     | No                                         |

* Click the `Launch DB Instance` button once everything is set.

Test Access
-----------

Once the RDS instance is set up, it should be accessible from the EC2 instance.
Test this by shelling into each EC2 instance and typing the following, using
the RDS endpoint host name:

    telnet xxxxxxxxx.rds.amazonaws.com 3306

Confirm that you see a "Connected to ..." message. Type Ctrl-D to exit the telnet shell.

Modify Security Groups
----------------------

To add a security group to an existing RDS instance:

* Go to the RDS dashboard in the AWS console,
* Select a single RDS instance to modify.
* `Instance Actions -> Modify -> Security Group`: update the allowed list of security groups.
* Click `Continue` and `Modify DB Instance` to save.
