edX AWS Analytics Deployment
============================

This document describes how to deploy the edX Analytics stack to the [Amazon Web Services].
We will be using [terraform] and [Ansible] to automate deployment where ansible playbooks are available, but some manual
setup is still required.

To deploy LMS/CMS, see [openEdx AWS deployment and upgrades](../aws-openedx/aws-deployment.md).

Prerequisites
=============

This document assumes a working edxapp setup exists, with an `edxapp` MySQL database, `ENABLE_OAUTH2_PROVIDER` set to
`true`, and tracking logs rotated into an S3 bucket, named something like `client-name-tracking-logs`.

To apply the terraform changes, you will need AWS credentials for an IAM User with [AdministratorAccess].

We run the analytics ansible playbooks from a separate EC2 `director` instance, with the
[edx/configuration] repository [and its dependencies installed](#director-ec2).

General Security Considerations
===============================

* Store your AWS credentials (key, secret) securely, and delete them when they are no longer required.
* Each set of instances (`analytics`, `director`, etc.) should have its own ssh keypair.
* Access between resources is granted by Security Groups, e.g. the edxapp RDS can be queried by the analytics
  EMR instances, because they are members of a Security Group which must be applied to the edxapp database.
* Default Jenkins setup is unprotected and allows anyone to do anything, so never allow external access to Jenkins (even
  briefly).  Close the 8080 port on instance with Jenkins to external world *before* running ansible script that
  installs Jenkins. Use [SSH tunneling](jenkins.md#ssh-tunneling-to-jenkins) to connect to it from your machine.

Sensitive Data
--------------

We will add our sensitive data, such as database passwords and key files, to a secure repo created for each client
deployment.  The files and their expected contents are discussed in subsequent sections.

* `analytics.pem` - AWS certificate for the analytics instance
* [`vars-analytics.yml`](resources/vars-analytics.yml) - ansible variables used to set up the analytics cluster.
  These variables can be stored in a separate file, or appended to the base `vars.yml` file used for the full edxapp
  setup.
* `analytics-tasks/`: Analytics-related configuration files
  * [`jenkins_env`](resources/jenkins_env): environment variables used when running analytics tasks via Jenkins
  * [`emr-vars.yml`](resources/emr-vars.yml): extra variables used to provision the EMR cluster
  * [`analytics-override.cfg`](resources/analytics-override.cfg): configuration for the analytics pipeline
  * [`edxapp_creds`](resources/creds_example) - contains readonly credentials to be used to access edxapp DBs (`edxapp`,
    `ecommerce`, etc.).
  * [`edxanalytics_creds`](resources/creds_example) - contains read-write credentials to be used to access analytics DBs
    (`analytics-api`, `reports`, etc.).

AWS Resources
=============

We will use terraform to create the following AWS resources in this setup.

**Note**: The service links below point to an older version of this documentation which created these services
manually. The details may be out of date now, but are provided for reference.

* One [EC2 instance] for hosting Insights (analytics dashboard), the Analytics API, and Jenkins (analytics
  scheduler).
  Alternatively, you may create a separate EC2 for each service, but ensure that they all share a security group.
* Two to five [S3 buckets].
* One [RDS] instance for Insights and Analytics API MySQL databases.
* One [ElasticSearch] instance.
* EMR clusters are provisioned on a per-task basis.
* Access between resources is controlled by [IAM].

# Terraform

## Setup terraform

1. [Install terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli).
1. Copy the files in [resources/terraform](resources/terraform/) to your client's secure repository.
1. Update the variables in [variables.tf](resources/terraform/variables.tf).
1. Set up an [AWS profile] locally. Use the `aws_profile` name and `aws_region` chosen in `variables.tf`.

## Initial creation

* Change directories to where you've stored your terraform `*.tf` files from [Setup](#setup-terraform).
* From the terminal, run:

   	```
   	# Downloads the terraform provider and source templates
   	terraform init

   	# Preview the changes that will be made (check these carefully)
   	terraform plan

   	# Apply those changes
	terraform apply
    ```

# MySQL database

The analytics databases and users need to be created manually.

## Create analytics databases and user

Create `dashboard`, `analytics-api`, and `reports` databases, and `analytics` user with password:

From the director instance, run the following command with the root RDS user to launch the mysql shell:

```bash
mysql -h analytics-rds-name.other-stuff.rds.amazonaws.com -u root -p
# Enter root user password
```

Run this SQL in the mysql shell:

```sql
CREATE DATABASE `dashboard` default character set utf8;
CREATE DATABASE `analytics-api` default character set utf8;
CREATE DATABASE `reports` default character set utf8;
CREATE USER 'analytics'@'%' IDENTIFIED BY '<analytics_password>';
GRANT ALL PRIVILEGES ON `reports`.* TO 'analytics'@'%';
GRANT ALL PRIVILEGES ON `dashboard`.* TO 'analytics'@'%';
GRANT ALL PRIVILEGES ON `analytics-api`.* TO 'analytics'@'%';
FLUSH PRIVILEGES;
```

Store the database credentials in [`vars-analytics.yml`](resources/vars-analytics.yml):

* `ANALYTICS_MYSQL_HOST`: 'analytics-rds-name.other-stuff.rds.amazonaws.com'
* `ANALYTICS_MYSQL_USER`: 'analytics'
* `ANALYTICS_MYSQL_PASSWORD`: 'analytics_password'
* `ANALYTICS_MYSQL_PORT`: '3306'

and in [`edxanalytics_creds`](resources/creds_example).

### Create migration user

Ansible tasks use common credentials for DB migration, which, by default are set to match edxapp credentials.
The easiest way to do this is to create a user in the analytics database with the same credentials as the edxapp mysql
user.  Use this commands to create the user in analytics db (replace `edxapp` and `<edxapp_password>` with your
actual DB user credentials):

```sql
CREATE USER 'edxapp'@'%' IDENTIFIED BY '<edxapp_password>';
GRANT ALL PRIVILEGES ON `reports`.* TO 'edxapp'@'%';
GRANT ALL PRIVILEGES ON `dashboard`.* TO 'edxapp'@'%';
GRANT ALL PRIVILEGES ON `analytics-api`.* TO 'edxapp'@'%';
FLUSH PRIVILEGES;
```

### Create edxapp read-only user

Some analytics tasks import data from `edxapp`-series DBs (`edxapp`, `ecommerce`, etc.).  Create a dedicated user with
readonly permissions *on the edxapp DB server*:

```bash
mysql -h edxapp-rds-name.other-stuff.rds.amazonaws.com -u edxapp -p
# Enter root user password
```

```sql
CREATE USER 'edxapp_ro'@'%' IDENTIFIED BY '<edxapp_ro_password>';
GRANT SELECT on *.* to 'edxapp_ro'@'%';
```

Store these credentials in [`edxapp_creds`](resources/creds_example).

Insights/Analytics API Setup
============================

See [Insights Setup](insights.md).

Jenkins Setup
=============

See [Jenkins Setup](jenkins.md).


[Amazon Web Services]: https://aws.amazon.com
[terraform]: https://www.terraform.io/
[Ansible]: https://www.ansible.com/
[AdministratorAccess]: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_job-functions.html#jf_administrator
[edx/configuration]: https://github.com/edx/configuration)
[EC2 instance]: https://github.com/open-craft/openedx-deployment/blob/v1.0/docs/analytics/AWS_setup.md#ec2
[S3 buckets]: https://github.com/open-craft/openedx-deployment/blob/v1.0/docs/analytics/AWS_setup.md#s3
[RDS]: https://github.com/open-craft/openedx-deployment/blob/v1.0/docs/analytics/AWS_setup.md#rds
[ElasticSearch]: https://github.com/open-craft/openedx-deployment/blob/v1.0/docs/analytics/AWS_setup.md#elasticsearch
[IAM]: https://github.com/open-craft/openedx-deployment/blob/v1.0/docs/analytics/AWS_setup.md#iam
[AWS profile]: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html
[Director Setup]: https://github.com/open-craft/openedx-deployment/blob/v1.0/docs/shared/director.md
