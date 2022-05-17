Jenkins Setup
=============

--------------------------

⚠️ Out of date
=============

**A newer version of this documentation is available at [https://doc.opencraft.com/analytics/jenkins/](https://doc.opencraft.com/analytics/jenkins/)**

A copy is below for historical purposes only.

--------------------------

See [AWS Setup](AWS_setup.md) to set up AWS resources and prepare secure configuration.

There are two ways to set up the Jenkins scheduler.  The patched `edx-analytics-configuration` playbook is being phased
out in favor of the `edx/configuration/playbook/analytics-jenkins.yml`, but many of our existing instances use the old
method, so be careful when updating an existing instance.

If you're updating an existing Jenkins instance, check your `vars-analytics.yml` file.  If it contains
`JENKINS_ANALYTICS_*` variables, then use [Option 1: `ansible-jenkins.yml`](#option-1-ansible-jenkins).  Otherwise, use
the patched `edx-analytics-configuration`.

If you're setting up a new Jenkins instance, use [Option 1:
`ansible-jenkins.yml`](#option-1-ansible-jenkins).

### Option 1. ansible-jenkins

Use the `edx/configuration` repository on the [director instance](../shared/director.md).  Ensure that it contains
the file `playbook/analytics-jenkins.yml`.  If not, consider merging the changes from `edx:master`, or using the
`edx-analytics-configuration` option below.

Variables and SSH Keys
----------------------

Update your [`vars-analytics.yml`](resources/vars-analytics.yml) to use the Jenkins scheduler configuration, and remove
the `edx-analytics-configuration` section.  See the [Jenkins Analytics
README](https://github.com/edx/configuration/blob/master/playbooks/roles/jenkins_analytics/README.md) for more
information about the variables in that file.

Ensure that the SSH key (e.g. `analytics.pem`) file can be used to shell into your Jenkins EC2 instance.

Run the playbook, e.g.:

```bash
workon edx-configuration
cd configuration/playbooks
ansible-playbook -i '1.2.3.4,' \
                 -e @/home/ubuntu/secure-config/vars-analytics.yml \
                 -u ubuntu \
                 --private-key=/home/ubuntu/secure-config/analytics.pem \
                 --skip-tags="jenkins-seed-job" \
                 analytics-jenkins.yml
```

#### Jenkins Seed Job

The steps in the `analytics-jenkins.yml` playbook tagged with `jenkins-seed-job` rely on the
[edx-ops/edx-jenkins-job-dsl repo](https://github.com/edx-ops/edx-jenkins-job-dsl), which is currently private.  The edX
Analytics team are working on making this repository public.  It contains DSL scripts which create the Jenkins jobs
automatically, and [configured by files in your secure configuration
repo](https://github.com/edx/configuration/blob/master/playbooks/roles/jenkins_analytics/README.md#jenkins-seed-job-configuration).

However, until that repo is opened up, we need to manually create the Jenkins jobs using the instructions in [Setting up
Jenkins](jenkins_jobs.md), and [copy the relevant files to `/home/jenkins`](#jenkins-env-and-configuration-overrides) so
they can be accessed by the analytics tasks.

To avoid seeing ansible errors about the seed job when running this playbook, we use the
`--skip-tags="jenkins-seed-job"` argument in the ansible command above.

#### Troubleshooting

* Jenkins is bound on IPv6: Make sure the [`vars-analytics.yml`](resources/vars-analytics.yml) file defines
  `jenkins_jvm_args` to contain `"-Djava.net.preferIPv4Stack=true"`.

### Option 2. edx-analytics-configuration

Checkout `open-craft/edx-analytics-configuration/analytics-sandbox` on the director instance, install requirements in
dedicated virtual environment, and run the `jenkins/scheduler.yml` playbook, passing vars from the `vars.yml` file.
Make sure to apply [`analytics-configuration` patches](https://github.com/open-craft/edx-analytics-configuration/commits/analytics-sandbox)
(commit range
[46ea75c](https://github.com/open-craft/edx-analytics-configuration/commit/46ea75c0b6affeb57d40535e84fe53103b686a1f)..[9d6ea8f](https://github.com/open-craft/edx-analytics-configuration/commit/9d6ea8fbba820840c879cdf2f370d7fb06338096))
for the playbook to run correctly.

Update your `vars-analytics.yml` to use the edx-analytics-configuration Jenkins scheduler section, not the
edx/configration Jenkins scheduler section.

Commands should look roughly like this:

```bash
workon edx-analytics-ansible
cd edx-analytics-configuration
ansible-playbook -i /path/to/analytics_hosts.lst \
                  -e @/path/to/vars.yml \
                  -u ubuntu \
                  --private-key=/path/to/edxapp.pem \
                  jenkins/scheduler.yml
```

#### Troubleshooting

* `locale.Error: unsupported locale setting` - by default Analytics/Insights instance have broken locale - [this
 AskUbuntu answer](http://askubuntu.com/a/229512) was helpful.
* Jenkins is bound on IPv6: by default Jenkins binds to `localhost`, which on some systems is translated to `::1` (IPv6
  notation). However, nginx proxy_pass [might not work with that](http://mgalgs.github.io/2013/05/04/localhost-considered-harmful.html).  
  Make sure [this commit](https://github.com/edx/edx-analytics-configuration/pull/32/commits/c97686586506677a5184181aa1ba0f7e610fceb8)
  is applied/cherry-picked and set `jenkins_prefer_ipv4` to true in `vars-analytics.yml`
* `jenkins_port`, `jenkins_external_port` and `INSIGHTS_NGINX_PORT` - first controls which port Jenkins app listens to.
  Second controls which port nginx reverse proxy uses to forward requests to  Jenkins app. Third is used by nginx
  reverse proxy to forward requests to Insights app. The three might conflict, preventing either Jenkins or Insights to
  be acessible from outside, or even fail to start nginx. Default values, are `8080`, `80` and `18110`, respectively.
  In this tutorial, we're confine Jenkins to AWS VPC only, by not exposing it to the world, while also allowind Insights
  to listen to 80 and 443 ports (default HTTP and HTTPS, in case you don't know :)). In this scenario, values should be
  `8080`, `8081` and `80`.

SSH Tunneling to Jenkins
------------------------

With current setup, Jenkins listens to port `8080`, but this port is only accessible from members of `director` Security
Group. In order to access it, we need to set up SSH tunneling:

    ssh -i director.pem -L 8080:analytics_ip:8080 ubuntu@director_ip

After establishing the tunnels you should be able to access Jenkins at `localhost:8080`

### Troubleshooting

* Can't connect to Jenkins:
  * Check tunneling is enabled
  * SSH to jenkins VM, and try connecting to `::1:8080` (localhost in IPv6 notation). If you get Jenkins response, try
    connecting to `127.0.0.1:8080` (localhost in IPv4 notation). If no response is available Jenkins have bound on IPv6
    only. Finally try connecting to `localhost:8080` - if no response is received, than system does not resolve
    `localhost` as both (?) IPv4 and IPv6 address.  See the **Troubleshooting** section in your preferred Jenkins setup
    section for how to fix this issue.

Configuring EMR clusters
========================

Any questions or issues related to the analytics configuration should be posted to the [Open edX Discourse
site](https://discuss.openedx.org/tag/analytics).

Configuration S3 bucket
-----------------------

Updating from EMR 2.x to EMR 4.x required [many changes to the analytics pipeline code, its dependencies, and
configuration](https://groups.google.com/forum/#!msg/openedx-ops/eCyNwYdhVcU/cOIHPLZiBwAJ).  See also [AWS: Differences
introduced in EMR 4.x](http://docs.aws.amazon.com/emr/latest/ReleaseGuide/emr-4.5.0/emr-release-differences.html)

### EMR 4.x

To set up the runtime environment for EMR 4.x, download these files from the OpenCraft AWS account, and upload to the
`client-name-analytics-emr` bucket:

* `mysql-connector-java-5.1.35.tar.gz` - java library for connecting to mysql.
  If we ever need an updated version, [obtain one from mysql.com](https://downloads.mysql.com/archives/c-j/), and modify
  the `install-sqoop` step in [`emr-vars.yml`](resources/emr-vars.yml) to pass `--mysql-connector-version=x.y.z`
  as a step argument.
* `edx-analytics-hadoop-util.jar` - java library for handling manifest files.
  Path referenced in [`analytics-override.cfg`](resources/analytics-override.cfg) setting `[manifest] lib_jar`, and
  requires [`analytics-override.cfg`](resources/analytics-override.cfg) setting
  `[manifest] input_format = org.edx.hadoop.input.ManifestTextInputFormat`.  Replaces `oddjob-1.0.1-standalone.jar`.
* [`install-sqoop`](https://github.com/edx/edx-analytics-configuration/blob/master/batch/bootstrap/install-sqoop) - use a version that supports EMR release 4.x.x

### EMR 2.4.11

AWS has dropped support for EMR 2.x.x, so use only when maintaining legacy analytics systems.  See
[resources/emr-2.x](resources/emr-2.x/) for example configuration files appropriate for this version.

Download these files from the OpenCraft AWS account, and upload to the `client-name-analytics-emr` bucket:

* `mysql-connector-java-5.1.35.tar.gz` - java library for connecting to mysql.
* `oddjob-1.0.1-standalone.jar` - java library for handling manifest files.
  Path referenced in [`analytics-override.cfg`](resources/analytics-override.cfg) setting `[manifest] lib_jar`, and
  requires [`analytics-override.cfg`](resources/analytics-override.cfg) setting
  `[manifest] input_format = oddjob.ManifestTextInputFormat`.
* `packages/*.deb` - store under a separate `packages` folder.
* `install-sqoop`
* `security.sh` - Before uploading to the client's S3, modify this script to
  fetch its `.deb` packages from the client's S3 bucket.

Pipeline S3 buckets
-------------------

Pipeline S3 bucket (named: `client-name-edxanalytics`) should contain the following files:

* `edxapp_creds` - contains credentials to be used to access edxapp DBs (`edxapp`, `ecommerce`, etc.). Readonly access
  is enough and preferred. Example: [creds_example](resources/creds_example)
* `edxanalytics_creds` - contains credentials to be used to access analytics DBs (`analytics-api`, `reports`, etc.).
  Read-write access is required. Example: [creds_example](resources/creds_example)
* `GeoIP.dat` - file that maps IP adresses to countries; used by `InsertToMysqlCourseEnrollByCountryWorkflow` task. A
  copy is provided [here](resources/GeoIP.dat).

File names can be overridden in [`analytics-override.cfg`](resources/analytics-override.cfg)

Jenkins Env and Configuration Overrides
---------------------------------------

Ensure these files exist on the analytics instance, and are backed up in the secure config repo:

* `/home/jenkins/jenkins_env`: environment variables used when running analytics tasks via
  Jenkins.  See [jenkins_env](#jenkins-env) below for details.
* `/home/jenkins/emr-vars.yml`: extra variables used to provision the EMR cluster.  See [emr-vars.yml](#emr-vars-yml)
  below for details.
* `/home/jenkins/analytics-override.cfg`: configuration for the analytics pipeline.  See
  [analytics-override.cfg](#analytics-override-cfg) below for details.

## Analytics repos

Also, ensure these repositories are cloned and readable by the jenkins user:

* `/home/jenkins/analytics-configuration`: clone the client's fork and branch, e.g.:

        analytics_configuration_repo: 'https://github.com/xxx/edx-analytics-configuration.git'
        analytics_configuration_version: 'master'

* `/home/jenkins/analytics-tasks`: clone the client's fork and branch, e.g.:

        analytics_pipeline_repo: 'https://github.com/xxx/edx-analytics-pipeline.git'
        analytics_pipeline_version: 'master'


## jenkins_env

Running pipeline jobs requires some environment variables to be set - these are listed in
[jenkins_env](resources/jenkins_env).  Variables include the [S3 buckets created above](#pipeline-s3-buckets) and others:

* `TRACKING_LOGS_S3_BUCKET="s3://client-name-tracking-logs"` - bucket containing edxapp tracking logs
* `HADOOP_S3_BUCKET="s3://client-name-edxanalytics"` - bucket for temporary/intermediate storage of hadoop files
* `TASK_CONFIGURATION_S3_BUCKET="s3://client-name-analytics-emr"` - bucket containing task configuration files
* `EXTRA_VARS="@/home/jenkins/emr-vars.yml"` - ansible configuration for provisioning EMR cluster.  See
  [emr-vars.yml](#emr-vars-yml) below.
* `CLUSTER_NAME="Client Name Analytics Cluster"` - default cluster name.  See [`CLUSTER_NAME`](#cluster_name) below.
* `OVERRIDE_CONFIG` - provides secure configuration variables to the EMR cluster.  See
  [analytics-override.cfg](#analytics-override-cfg) below.

### CLUSTER_NAME

The [`emr-vars.yml`](resources/emr-vars.yml) file defines a `name` variable, which is the identifier for the EMR
cluster.  However, the analytics scripts use `CLUSTER_NAME` to lookup the cluster, and so these variables *must* match,
otherwise the lookup will fail.  Additionally, it's a good idea to use a different `CLUSTER_NAME` for each analytics
task, to allow them to run in parallel on different clusters.  To achieve this, we override the default `CLUSTER_NAME`
with a unique name for each analytics task in its [Jenkins Job Command](jenkins_jobs.md#Commands).

So to ensure that the [`emr-vars.yml`](resources/emr-vars.yml) cluster `name`
matches the `CLUSTER_NAME` environment variable, use a lookup:

```yaml
---
name: "{{ lookup('env', 'CLUSTER_NAME') }}"
```

## analytics-override.cfg

The `OVERRIDE_CONFIG` in `jenkins_env` points to this file.  It is used to provide secure configuration variables to EMR
cluster and should look like [analytics-overide.cfg](resources/analytics-override.cfg).  This file contains links to S3
EMR config, EMR log and tracking log S3 buckets - example uses S3 bucket names suggested in this walkthrough.

Note that default `edx-analytics-pipeline` uses [different approach][upstream-secure-config] to provide secure config:

* `--secure-config-repo $SECURE_REPO` - specifies GIT repo with secure configuration.
* `--secure-config-branch $SECURE_BRANCH` - specifies branch in that repo to be used.
* `--secure-config $SECURE_CONFIG` - specifies configuration file in that repo to be used.

Make sure to check what approach is used in current setup branches and alter `jenkins_env` accordingly.

[upstream-secure-config]: https://github.com/edx/edx-analytics-configuration/blob/master/automation/run-automated-task.sh#L34

## emr-vars.yml

The `emr-vars.yml` file is passed to the ansible playbook that handles EMR provisioning.  See
[emr-vars.yml](resources/emr-vars.yml) for an example.  You'll need to update the S3 bucket names as per the [S3
buckets](AWS_setup.md#s3) you created.

### AWS region

Open edX Analytics is complex to set up, and so is not used by that many organizations outside of edX. Therefore, some
assumptions made in the code and configuration are specific to edX's region and requirements.

edX runs on the `us-east-1` AWS region, which is also the default region for many AWS actions.  There are places in the
analytics pipeline and configuration to configure the region used, but they don't always work.

OpenCraft have successfully run Open edX Analytics on `eu-west-1` and `ca-central-1` regions, but both required minor
configuration and code changes. Unfortunately, it's unlikely to be cost-effective to upstream these changes, so they
remain as code drift that have to be carried through across version upgrades.

Here are the changes required to use regions other than `us-east-1` for Open edX Analytics:

* In [jenkins_env], set `AWS_REGION` to your desired region.
* In [emr-vars.yml], set `region` to your desired region.
* In [emr-vars.yml], specify the `fs.s3n.endpoint: "s3.amazonaws.com"`. See the [configuration: core-site] block for details.
* Patch the `TASK_BRANCH` used in [jenkins_env] and [cloned to jenkins home] to use your desired region: [TASK_BRANCH patch]

  Allows us to override the default S3 endpoint to use a custom region.
1. Patch the `CONFIG_BRANCH` used in [jenkins_env] and [cloned to jenkins home]: [CONFIG_BRANCH patch]

  Allows us to use the more consistent `ONDEMAND` pricing for the EMR task instances, instead of edX's default `SPOT`
  pricing.

### SigV4 authentication

Amazon have [deprecated their S3 v2 authentication model][AWS deprecated SigV2], but it's still supported on existing S3
buckets in some regions like `us-east-1`.

In `ca-central-1` and other newer AWS regions, only the new [SigV4 mechanism][AWS SigV4] is supported.

This change is required to support SigV4:

* In [emr-vars.yml], use `release_label: 'emr-4.9.6'`

  Using [EMR version 4.9.6] causes EMR to use AWS Signature Version 4 exclusively to authenticate requests to Amazon S3.


Jenkins analytics jobs
----------------------

See [Jenkins Jobs](jenkins_jobs.md) for how to manually create the jenkins jobs.

See the [Jenkins Seed Job](#jenkins-seed-job) section for information on automatic Jenkins job creation.

Troubleshooting
---------------

* EMR provisioning: ansible unable to access new EMR instance.  See [SSH Access to EMR](#emr-security-groups).
  Ensure the `ElasticMapReduduce-master` security group has inbound SSH access from the analytics security group.

    Another way to provide Jenkins with access is to to set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` variables in
  `jenkins_env`, however it's very important to ensure that your Jenkins logs are not publicly visible, because these
  variables will be echoed to the Console output.

    To use AWS keys, create a new analytics IAM user and use the ID and KEY for these variables. Note that this user
  should have `provision_emr_clusters` policy attached, otherwise trying to provision the cluster will fail with:
    > ClientError: An error occurred (AccessDeniedException) when calling the ListClusters operation: User: arn:aws:iam::123456789012:user/analytics_user is not authorized to perform: elasticmapreduce:ListClusters

* `java.lang.UnsupportedClassVersionError: org/edx/hadoop/input/ManifestTextInputFormat : Unsupported major.minor version 51.0` or `52.0`.  This error occurs if the `edx-analytics-hadoop-util.jar` you're using for your
  `manifest.lib_jar` was compiled using a different version of java than what's running on the EMR cluster.
  The easiest way to rebuild the `edx-analytics-hadoop-util.jar` using the correct java version, and the required hadoop
  libraries, is to:

    1. Launch an EMR cluster using the version of EMR configured for your analytics tasks.

        Alternately, run one of the failing tasks with `export TERMINATE=false`
        in the environment, and this will leave the EMR cluster running after
        the job has failed.

        Note the EMR Cluster ID for the `aws emr` step below.
    1. Create a virtualenv, and install awscli:

            pip install awscli

    1. Create an IAM user and attach the `provision_emr_clusters` policy you created above.
    1. Using the AWS Access key ID and secret, authenticate your awscli:

            aws configure

  1. Shell into the EMR cluster using the `analytics.pem` file:

        aws emr ssh --cluster-id j-xxxxxxxxxxxx --key-pair-file=analytics.pem

  1. Clone the edx-analytics-hadoop-util repo, and build the jar file:

        git clone https://github.com/edx/edx-analytics-hadoop-util
        cd edx-analytics-hadoop-util
        javac -cp "/usr/lib/hadoop/client/*" org/edx/hadoop/input/ManifestTextInputFormat.java
        jar cf edx-analytics-hadoop-util.jar org/edx/hadoop/input/ManifestTextInputFormat.class


* EMR provisioning fails on the `hive_install` step with the following in stderr log:

  > Exception in thread "main" com.amazon.ws.emr.hadoop.fs.shaded.com.amazonaws.services.s3.model.AmazonS3Exception: Moved Permanently (Service: Amazon S3; Status Code: 301; Error Code: 301 Moved Permanently; Request ID: A80C873649993B68), S3 Extended Request ID: z0mA1W5N329bG+Sznq/j7G2g5gsRgKWlzqdoRmYVoCIyELiv0CNk+hmbcm2fkd7G30c7Gzs7xXk=

  May occur if you're running on a region other than `us-east-1`.  See [emr-vars.yml](resources/emr-vars.yml)
  configuration for `core-site` to set the `fs.s3n.endpoint`.

* EMR provisioning fails during provisioning with:

  > The subnet configuration was invalid: No route to any external sources detected in Route Table for Subnet: subnet-xxxxx for VPC: vpc-xxxxx

  This could mean you have not created an Internet Gateway for your VPC. See [VPC DNS Hostname](AWS_setup.md#vpc-dns-hostname)


[jenkins_env]: resources/jenkins_env
[emr-vars.yml]: resources/emr-vars.yml
[cloned to jenkins home]: #analytics-repos
[configuration: core-site]: resources/emr-vars.yml#L39-L44
[AWS deprecated SigV2]: https://aws.amazon.com/blogs/aws/amazon-s3-update-sigv2-deprecation-period-extended-modified/
[AWS SigV4]: https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-authenticating-requests.html
[EMR version 4.9.6]: https://docs.aws.amazon.com/emr/latest/ReleaseGuide/emr-release-4x-details.html#emr-496-release
[CONFIG_BRANCH patch]: https://github.com/edx/edx-analytics-configuration/compare/open-release/koa.2a...open-craft:opencraft-release/koa.2a
[TASK_BRANCH patch]: https://github.com/edx/edx-analytics-pipeline/compare/open-release/koa.2a...open-craft:opencraft-release/koa.2a-ubc
