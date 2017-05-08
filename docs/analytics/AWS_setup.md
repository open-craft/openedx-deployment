edX AWS Analytics Deployment
============================

This document describes how to deploy the edX Analytics stack to the [Amazon Web Services](https://aws.amazon.com). We
will be using [Ansible](https://www.ansible.com/) to automate deployment where ansible playbooks are available, but some
manual setup is still required.

Prerequisites
=============

This document assumes a working edxapp setup exists, with an `edxapp` MySQL database, `ENABLE_OAUTH2_PROVIDER` set to
`true`, and tracking logs rotated into an S3 bucket, named something like `client-name-tracking-logs`.

We run the analytics ansible playbooks from a separate EC2 `director` instance, with the
[`edx/configuration`](https://github.com/edx/configuration) repository [and its dependencies
installed](#director-ec2).

General Security Considerations
===============================

* Each set of instances (`analytics`, `director`, etc.) should have its own ssh keypair.
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

We will create the following AWS resources in this setup:

* One [EC2 instance](#ec2) for hosting Insights (analytics dashboard), the Analytics API, and Jenkins (analytics
  scheduler).
  Alternatively, you may create a separate EC2 for each service, but ensure that they all share a security group.
* Two to five [S3 buckets](#s3).
* One [RDS](#rds) instance for Insights and Analytics API MySQL databases.
* One [ElasticSearch](#elasticsearch) instance.
* EMR clusters are provisioned on a per-task basis.
* Access between resources is controlled by [IAM](#iam).

IAM
---

The following Identity Access Management (IAM) users, roles, and policies are used by the analytics services.

### Provision EMR Clusters

The Jenkins instance will need to launch and terminate EMR clusters.

We will create an IAM role for the `analytics` EC2 instance, to give it permission to provision EMR clusters.

* Go to `IAM -> Policies -> Create Policy`
* Select "Create Your Own Policy"
* Give it a recognizable name (eg. `provision_emr_clusters`)
* Paste this into "Policy Body" and click "Create":

```json
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Effect": "Allow",
          "Resource": "*",
          "Action": [
              "elasticmapreduce:*",
              "iam:PassRole",
              "route53:Get*",
              "route53:List*",
              "ec2:DescribeInstances",
              "rds:DescribeDBInstances"
          ]
      }
  ]
}
```

* Now go to `IAM -> Roles -> Create New Role`
* Give it a recognizable name (eg. `edxanalytics`)
* Select `Amazon EC2` role type on next step
* Select the policy you created above (eg. `provision_emr_clusters`)
* Hit "Create Role" on final step

### ElasticSearch User

The analytics API needs to be able to read indexes from the AWS ElasticSearch instance.

* Go to `IAM -> Policies -> Create Policy`
* Select "Create Your Own Policy"
* Give it a recognizable name (eg. `elasticsearch_all`)
* Paste this into "Policy Body":

```json
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Effect": "Allow",
          "Resource": "*",
          "Action": [
              "es:*"
          ]
      }
  ]
}
```

* Go to `IAM -> Users -> Add User`
* Give it a recognizable name (eg. `analytics_elasticsearch`)
* Give it Programmatic access
* Attach the policy you created above (eg. `elasticsearch_all`)
* Copy the security credentials to the [`vars-analytics.yml`](resources/vars-analytics.yml) fields:
  * `ANALYTICS_API_ELASTICSEARCH_AWS_ACCESS_KEY_ID`: the Access Key ID goes here, e.g. `AKIA0123456789ALPHAB`
  * `ANALYTICS_API_ELASTICSEARCH_AWS_SECRET_ACCESS_KEY` the Secret Access Key goes here, e.g.
      `abcdefghijklmnopqrstuvwxyz01234567899/_+`.

### EMR Roles

The simplest way to generate the EMR IAM roles is to let AWS do it automatically:

* Go to the EMR dashboard in AWS console.
* Click "Create Cluster"
* Make sure "Permissions" are set to `Default`
* Note that we only need IAM roles created autyomatically, so set `Instance Type` to the smallest instance available
* Click "Create cluster"
* Check that these default roles and security groups are automatically generated:
  * `EMR_DefaultRole`: default EMR role
  * `EMR_EC2_DefaultRole`: role used by our standard [emr-vars.yml](resources/emr-vars.yml) configuration file.
  * `ElasticMapReduce-master`: security group for the EMR master instances.
  * `ElasticMapReduce-slave`: security group for the EMR slave instances.
* You can now click "Terminate" to kill the cluster.

To allow the EMR resources to write to the ElasticSearch index:

* Go to `IAM -> Roles` and locate the `EMR_EC2_DefaultRole`.
* Attach the ElasticSearch policy created above (`elasticsearch_all`).

### EMR Security Groups

To allow SSH access from the analytics instance to the EMR, we need to edit the EMR master security group.

* Go to the EC2 dashboard in AWS console.
* Click on 'Network & Security: Security Groups'
* Select the `ElasticMapReduce-master` security group and Edit the Inbound rules.
* Add Inbound SSH access from the analytics security group:
  * `SSH`, port `22`, source `analytics` Security Group

The analytics pipeline needs to be able to access the `analytics` and `edxapp` databases.

To do so, create an `EMR RDS` security group with the following rules:

* `MYSQL/Aurora`, port `3306`, source `ElasticMapReduce-master` Security Group
* `MYSQL/Aurora`, port `3306`, source `ElasticMapReduce-slave` Security Group.

### `grades-download` Permissions

Some Jenkins jobs (e.g. `StudentEngagementCsvFileTask`) require downloads to be placed in the `grades-download`
directory of the edxapp S3 bucket. In order for the resulting files to be downloadable from the instructor dashboard,
permissions on the bucket must be set as follows:

* Go to `S3` and select the bucket configured by `EDXAPP_GRADE_BUCKET`.
* Select `Permissions` and then select `Edit bucket policy`
* Paste the following into the `Bucket Policy Editor`:
  * Replace `my-edxapp-bucket` with the name of the bucket
  * Replace `arn:aws:edxapp-user` with the ARN for your edxapp AWS user (access granted via `EDXAPP_AWS_ACCESS_KEY_ID`
    and `EDXAPP_AWS_ACCESS_KEY_SECRET`).

```json
{
  "Version": "2008-10-17",
  "Id": "...",
  "Statement": [
      {
          "Sid": "some-unique-identifier",
          "Effect": "Allow",
          "Principal": {
              "AWS": "arn:aws:edxapp-user",
          },
          "Action": "s3:GetObject",
          "Resource": "arn:aws:s3:::my-edxapp-bucket/grades-download/*"
      }
  ]
}
```

### Analytics API Reports

Do this step only if your client requires the Problem Response Reports.

The pipeline task `ProblemResponseReportWorkflow` generates reports and stores them to S3.  The analytics API sends
links to these report files to Insights.  So we need to create an IAM user with read access to the analytics-api report
bucket.

* Go to `IAM -> Users -> Create New User`
* Give it a recognizable name (eg. `analytics_reports`)
* Create security credentials, and copy them to `vars-analytics.yml` fields under
  `ANALYTICS_API_REPORT_DOWNLOAD_BACKEND`:

  * `AWS_ACCESS_KEY_ID`: the Access Key ID goes here, e.g. `AKIA0123456789ALPHAB`
  * `AWS_SECRET_ACCESS_KEY` the Secret Access Key goes here, e.g. `abcdefghijklmnopqrstuvwxyz01234567899/_+`.
  * `AWS_STORAGE_BUCKET_NAME`: the S3 bucket created for the analytics-api reports goes here, e.g.
    `client-name-analytics-api-reports`
* Under Permissions, create an `Inline Policy -> Custom Policy`
* Give it a recognizable name (eg. `s3-read-analytics-reports`)
* Paste this into "Policy Body", with the correct bucket name replaced where
  `client-name-analytics-api-reports` is used below.

  *Note*: the Resource `"arn:aws:s3:::client-name-analytics-api-reports"` refers to the top-level bucket access, and
   `"arn:aws:s3:::client-name-analytics-api-reports/*"` refers to all the files stored inside the bucket.  Both resource statements are required.

 ```json
    {
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:Get*",
                    "s3:List*"
                ],
                "Resource": [
                    "arn:aws:s3:::client-name-analytics-api-reports",
                    "arn:aws:s3:::client-name-analytics-api-reports/*"
                ]
            }
        ]
    }
   ```
   - Click "Create"

* Select `Save`

### VPC DNS hostname

Ensure DNS hostnames are enabled in the VPC where your EMR jobs will be running.  If DNS hostnames are disabled, EMR
provisioning will be stuck at `provisioning`.  To check whether DNS hostnames are enabled:

* Go to the AWS VPC dashboard, and select your VPC.
* Check the value of "DNS hostnames" in the Summary tab/pane. If it says `no`, click `Actions -> Edit DNS Hostnames`,
  select `Yes`, and save.

### VPC Subnet

* Go to the AWS VPC dashboard, and select Subnets
* Ensure that one of the subnet IDs listed in the Subnets list is in the `vpc_subnet_id` variable in [`emr-vars.yml`](resources/emr-vars.yml).

ElasticSearch
-------------

The Analytics Pipeline's Learner tasks write their statistics to an ElasticSearch index, which is read by the Analytics
API's Learner API to display in Insights.

* Go to `Analytics -> Elasticsearch Service -> Create a new domain`
* Make sure the ES instance is being created under the correct AWS region.  It should match your EC2 region, and
  [`ANALYTICS_API_ELASTICSEARCH_CONNECTION_DEFAULT_REGION`](resources/vars-analytics.yml#L59).
* Choose a unique domain name, e.g. `client-name-analytics-es`
* Select Elasticsearch version 1.5
* Node configuration:
  * Instance count: 1
  * Instance type: `t2.small.elasticsearch`
  * Enable dedicated master: no
  * Enable zone awareness: no
  * Storage type: EBS
  * EBS volume type: General Purpose (SSD)
  * EBS volume size: 10GB
  * Automated snapshot start hour: 00:00 UTC (default)
  * Advanced options: `rest.action.multi.allow_explicit_index: true`

In around 10 minutes, the new ElasticSearch domain will be created.  Paste the `Endpoint` (e.g.
`https://search-client-name-analytics-es-xxxxx.eu-west-1.es.amazonaws.com`) into two places:

* `vars-analytics.yml`: [`ANALYTICS_API_ELASTICSEARCH_LEARNERS_HOST`](resources/vars-analytics.yml#L60)
* `analytics-override.yml`: [`[elasticsearch] host`](resources/analytics-override.cfg#L48)

EC2
---

Click the *Launch Instance* button on the EC2 Dashboard, and follow the steps to configure the instance.  If you are
creating separate instances for Insights, Analytics API, and/or Jenkins, then create an EC2 for each service.

Most other configuration steps you can leave at their default values, unless specified below:

1. Community AMI - use [Ubuntu Cloud Images Locator](https://cloud-images.ubuntu.com/locator/) to find a recent *Ubuntu
   16.04 LTS (Xenial Xerus)* build.
   Search for version 16.04 amd64 `ebs-ssd` or `hvm-ssd` instance in your preferred AWS region, for example us-east-1.
   Copy the AMI ID of the image you selected (it will look something like `ami-d8132bb0`).
1. Choose Instance Type - General Purpose `t2.medium`.
1. Configure Instance
    1. Ensure the Network setting is set to the default VPC, *not* EC2-Classic.
    1. Assign `edxanalytics` IAM role.
       **Important**: roles can't be added after instance is launched, so forgetting to set this setting will require
       instance re-launch (and re-provisioning and re-configuring, depends on how late you noticed the problem).
1. Add Storage - 50GB
1. Tag Instance - `Name` tag with `analytics-N` value.
1. Security Group - add instance to `default` and `analytics` security groups.
   If `analytics` is not created yet - create it with the following rules:
    * `SSH`, port `22`, source `director` security group
    * `HTTP`, port `80`, source `Anywhere` (used to access the Insights over http)
    * `HTTPS`, port `443`, source `Anywhere` (used to access the Insights over https)
1. SSH key pair - use `analytics` key pair (create if needed).

Note that Insights runs on 18110 port by default, and we're not opening it, so it should be configured to listen on
default HTTP and/or HTTPS ports with `INSIGHTS_NGINX_PORT` variables `INSIGHTS_NGINX_SSL_PORT` in
[`vars-analytics.yml`](resources/vars-analytics.yml).

After the instance is fully initialized, SSH into it using the key file you used when creating this instance:

```bash
ssh -i path/to/keyfile.pem ubuntu@ec2-xx-xx-xx-xx.compute-1.amazonaws.com
```

Install all available updates with:

```bash
sudo apt-get update && sudo apt-get -y upgrade
```

### Director EC2

The `director` instance should be running a similar version of Ubuntu as the analytics services you're provisioning.  It
can be a `t2.micro`, with 8GB disk space, and should be a member of the `default` Security Group shared by your other
AWS resources, and a `director` security group with one rule defined:

* `SSH`, port `22`, source `Anywhere`

See [Director Setup](../shared/director.md) for details on how to set up the ansible deployment "director" instance.

RDS
---

If you're upgrading an existing analytics deployment, we strongly recommend you create a new RDS instance, and re-run
the following steps.  Schema changes aren't well handled in analytics-land yet, and so it's best to let the analytics
tasks and API deployment process create their tables and fields.

* Launch a new `analytics` RDS instance (see [RDS](../shared/RDS.md)).
* Ensure that both the new `analytics` RDS, and the existing `edxapp` RDS, are members of the [`EMR RDS` security group](#emr-security-groups) created above.

  See [Modify Security Groups](../shared/RDS.md#modify-security-groups) for instructions on how to add a security group to an existing RDS instance.

* [Test the RDS instance](../shared/RDS.md#test-access) from the Insights/Analytics API instance to ensure it can connect to the new RDS instance.

### Create analytics databases and user

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

Elastic IP
----------

Create new Elastic IP and associate it with Insights EC2 instance (see [Elastic IP](../shared/Elastic_IP.md)).

S3
--

Create the required S3 buckets:

* `client-name-tracking-logs`: for storing tracking logs emitted by LMS and sharing them with analytics pipeline.
  (May already be created, see [prerequisites](#prerequisites) above.)
* `client-name-analytics-emr` - for initial EMR cluster provisioning and logs. Some setups may use a separate
  bucket for EMR logs, e.g. `client-name-analytics-emr-logs`.  See [Configuration S3
  bucket](jenkins.md#configuration-s3-bucket) for the list of files that need to be uploaded to this bucket.
* `client-name-edxanalytics` - for analytics pipeline configuration (access credentials, GeoIP data, etc.) and data
  (hadoop, hive).  Some setups may use a separate bucket for Hive/hadoop, e.g.  `client-name-edxanalytics-hadoop`.  See
  [Pipeline S3 bucket](jenkins.md#pipeline-s3-bucket) for the list of files that need to be uploaded to this bucket.
* `client-name-analytics-api-reports` - used to share reports generated by the analytics pipeline with the analytics API.  Only required for some analytics pipeline tasks (e.g. `ProblemResponseReportWorkflow`).


Insights/Analytics API Setup
============================

See [Insights Setup](insights.md).

Jenkins Setup
=============

See [Jenkins Setup](jenkins.md).
