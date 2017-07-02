Setting up Jenkins
==================

See [Jenkins Setup](jenkins.md) to set up a Jenkins instance.

EdX analytics pipeline comes equipped with a lot of tasks to perform various analytics calculations, but it
intentionally lacks any mechanism to run them periodically. EdX suggests using cron jobs or Jenkins builds. This
document provides instructions on setting up Jenkins jobs to run analytics tasks periodically

Create an [SSH tunnel](jenkins.md#ssh-tunneling-to-jenkins) to connect to the secure Jenkins instance.

Configuring Jenkins
-------------------

To configure Jenkins to send error emails, go to the main page:

* Click "Manage Jenkins" in the left sidebar.
* Click "Configure System".
* Scroll down to "Jenkins Location > System Admin e-mail address".
* Enter an email address that is an allowed From address for the SMTP provider used by postfix on the analytics server,
  e.g. the `EDXAPP_SERVER_EMAIL` from your edxapp `vars.yml` file.

To increase the number of Jenkins tasks that can run in parallel (e.g. if you're going to be scheduling tasks to run
hourly):

* Click "Manage Jenkins" in the left sidebar.
* Click "Configure System".
* Locate the "# of executors" field near the top.
* Increase this to the desired number of processes, e.g. 3.

Also note that if you're going to have Jenkins tasks running in parallel, they should be [configured to use different
`CLUSTER_NAME` values](jenkins.md#cluster_name) so they don't terminate EMR clusters out from under one another.  See
the sample task configurations for examples of `CLUSTER_NAME` values.

Configuring Jenkins job
-----------------------

To create job, authenticate to Jenkins, than go to main page.

* Click "New Item" in the left sidebar. Once you've created the first task, you can "Copy from existing item" instead, which saves a lot of steps.
* Set the task name to be the insights domain, followed by a recognizable name that uniquely identifies the task (e.g. "insights.example.com Module Engagement"). Having the insights domain prepended to the task name will help recipients of the error emails to quickly identify the source analytics instance of any future task failure alerts.
* Select "Build a free-style software project"
* You'll arrive at job configuration page. `Name` should be already set automatically. You might want to give task a description.
* No modifications required in `Job Notifications` and `Advanced Project Options` sections.
* `Source Code Management` - `None`
* `Build Triggers` - `Build Periodically`. `H X * * *` should be good value for `Schedule field`, with X being an hour to run task (i.e. with X=19 task will run an 19:00 daily), `H` being Jenkins feature to spread the load; refer to Jenkins help should more need for a more sophisticated schedule arise.
* `Build Environment` -> `Abort the build if it's stuck`: Enable this option. Set `Time-out strategy` to `Absolute`, `Timeout Minutes` to `300`. Then click `Add Action` and add a timeout action of `Fail the Build`.
* `Build Environment` -> `SSH Agent` -> `Credentials` -> `Specific credentials`: This allows Jenkins to ssh to the
  EMR servers via the shell command. Select the 'hadoop' ssh access key created by ansible. If the ssh credentials were not configured via ansible you can manually create a key here by clicking the
  `Add Key` button.
  * Kind: SSH username with private key
  * Scope: Global
  * Username: `hadoop`
  * Private key: paste the analytics private key file contents directly, or copy the file to the analytics instance and point to the path.
  * Passphrase: Leave empty for AWS-issued private key files.
  * Description: ssh credential file
* `Build` -> `Add Step` -> `Execute Shell`.
* Fill in `Command` field with shell script to run. See [Commands](#commands) for details.
* `Post build actions` -> `Add post build task` ->
  * `Log text`: `Traceback`
  * `Script`: `exit 1`
  * `Run script only if all previous steps were successful`: `yes`
  * `Escalate script execution status to job status`: `yes`
* `Post build actions` -> `Add post build action` -> `Email Notification`
  * `Recipients` - an alert email address, e.g. `ops@example.com`
  * `Send e-mail for every unstable build`: `yes`
  * `Send separate e-mails to individuals who broke the build`: `no`
* Finally, click `Save`

It makes sense to try to produce even load on the server by running tasks throughout the day, i.e. not put them all to
`0 0 * * *`, or even `H H * * *` (`H` is a hash, so it might put some tasks closely together).

# Commands

These example commands rely heavily on environment variables defined in [`jenkins_env`](resources/jenkins_env).  See
[Jenkins Env and Configuration Overrides](jenkins.md#jenkins-env-and-configuration-overrides) for a
discussion of these environment variables.

One can do without a `jenkins_env` file by omitting the `. /home/jenkins/jenkins_env` command from the shell script
body, and list the environment variables in the actual shell command inline.

## Answer Distribution

Performance (Graded and Ungraded); runs nightly.

Run on periodic build schedule, e.g. `H 0 * * *`.

NB: The AnswerDistributionWorkflow task is one of the oldest analytics tasks, and not as cleanly configured as the other
tasks.  The `--dest`, `--manifest`, and `--marker` parameters must used a timestamped directory, to ensure fresh data
for each run of the task.

```bash
. /home/jenkins/jenkins_env
export CLUSTER_NAME="AnswerDistributionWorkflow Cluster"
cd $HOME

NOW=`date +%s`
ANSWER_DIST_S3_BUCKET=$HADOOP_S3_BUCKET/intermediate/answer_dist/$NOW

analytics-configuration/automation/run-automated-task.sh AnswerDistributionWorkflow \
    --local-scheduler \
    --src $TRACKING_LOGS_S3_BUCKET/logs/tracking \
    --dest "$ANSWER_DIST_S3_BUCKET" \
    --name AnswerDistributionWorkflow \
    --output-root $HADOOP_S3_BUCKET/grading_reports/ \
    --include '*tracking.log*.gz' \
    --manifest "$ANSWER_DIST_S3_BUCKET/manifest.txt" \
    --base-input-format "org.edx.hadoop.input.ManifestTextInputFormat" \
    --lib-jar "$TASK_CONFIGURATION_S3_BUCKET/edx-analytics-hadoop-util.jar" \
    --n-reduce-tasks $NUM_REDUCE_TASKS \
    --marker "$ANSWER_DIST_S3_BUCKET/marker"
```

## Enrollments Total, Enrollments by Gender, Age, Education

Imports enrollments data; runs daily.

Run on periodic build schedule, e.g. `H 6 * * *`.

```bash
. /home/jenkins/jenkins_env
export CLUSTER_NAME="ImportEnrollmentsIntoMysql Cluster"
cd $HOME

TO_DATE=`date +%Y-%m-%d`
analytics-configuration/automation/run-automated-task.sh ImportEnrollmentsIntoMysql \
    --local-scheduler \
    --interval "2013-01-01-$TO_DATE" \
    --n-reduce-tasks $NUM_REDUCE_TASKS
```

## Enrollments By Country

Enrollments by geolocation; runs daily.

Run on periodic build schedule, e.g. `H 12 * * *`.

```bash
. /home/jenkins/jenkins_env
export CLUSTER_NAME="InsertToMysqlCourseEnrollByCountryWorkflow Cluster"
cd $HOME

NOW=`date +%s`
analytics-configuration/automation/run-automated-task.sh InsertToMysqlCourseEnrollByCountryWorkflow \
    --local-scheduler \
    --n-reduce-tasks $NUM_REDUCE_TASKS \
    --overwrite
```

## Course Activity

Weekly course activity; runs daily.

Run on periodic build schedule, e.g. `H 3 * * *`.

```bash
. /home/jenkins/jenkins_env
export CLUSTER_NAME="CourseActivityWeeklyTask Cluster"
cd $HOME

TO_DATE=`date +%Y-%m-%d`
analytics-configuration/automation/run-automated-task.sh CourseActivityWeeklyTask \
    --local-scheduler \
    --end-date $TO_DATE \
    --weeks 24 \
    --n-reduce-tasks $NUM_REDUCE_TASKS
```

## Module Engagement - bootstrap task

The primary entry point `ModuleEngagementWorkflowTask` is run daily and updates the elasticsearch index and MySQL
database with the aggregates computed from the last 7 days of activity.

Before scheduling `ModuleEngagementWorkflowTask`, we run `ModuleEngagementIntervalTask` once to populate the historical
data in the `module_engagement` table in MySQL. This table is updated incrementally every night (by the primary entry
point), however, it needs to be bootstrapped when you first start running the system with a bunch of historical data.

Do not run on a periodic build schedule; run manually once when deploying analytics for a client with historical
tracking data.  Beware that this task can take several hours to complete, so choose a conservative `FROM_DATE`.

```bash
. /home/jenkins/jenkins_env
export CLUSTER_NAME="ModuleEngagementInterval Cluster"
cd $HOME

FROM_DATE=2016-01-01  # choose an early date from existing tracking logs
TO_DATE=`date +%Y-%m-%d`
analytics-configuration/automation/run-automated-task.sh ModuleEngagementIntervalTask \
    --local-scheduler \
    --interval $FROM_DATE-$TO_DATE \
    --overwrite-from-date $TO_DATE \
    --overwrite-mysql \
    --n-reduce-tasks $NUM_REDUCE_TASKS
```

## Module Engagement

Weekly course module engagement data stored in an ElasticSearch index; runs daily.

Run on periodic build schedule, e.g. `H 15 * * *`.

Note: HKS epodX wanted theirs to run every 2 hours, so for them we use: `H */2 * * *`,

```bash
. /home/jenkins/jenkins_env
export CLUSTER_NAME="ModuleEngagementWorkflowTask Cluster"
cd $HOME

TO_DATE=`date +%Y-%m-%d`
analytics-configuration/automation/run-automated-task.sh ModuleEngagementWorkflowTask \
    --local-scheduler \
    --date $TO_DATE \
    --n-reduce-tasks $NUM_REDUCE_TASKS
```

## Videos

Tracks video interactions; runs daily.

Run on periodic build schedule, e.g. `H 9 * * *`.

```bash
. /home/jenkins/jenkins_env
export CLUSTER_NAME="InsertToMysqlAllVideoTask Cluster"
cd $HOME

FROM_DATE=2010-01-01
TO_DATE=2030-01-01
analytics-configuration/automation/run-automated-task.sh InsertToMysqlAllVideoTask --local-scheduler \
  --interval $(date +%Y-%m-%d -d "$FROM_DATE")-$(date +%Y-%m-%d -d "$TO_DATE") \
  --n-reduce-tasks $NUM_REDUCE_TASKS
```

## Student Engagement

### Daily Reports

Run on a daily build schedule, e.g. `H 19 * * *`.

```bash
. /home/jenkins/jenkins_env
export CLUSTER_NAME="StudentEngagementCsvFileTaskDaily Cluster"
cd $HOME

FROM_DATE=$(date +%Y-%m-%d --date="-1 day")
TO_DATE=$(date +%Y-%m-%d)
NOW=`date +%s`

analytics-configuration/automation/run-automated-task.sh StudentEngagementCsvFileTask --local-scheduler \
  --output-root "$EDXAPP_S3_BUCKET/grades-download/" \
  --marker "$HADOOP_S3_BUCKET/intermediate/student_engagement/$NOW/marker" \
  --interval "$FROM_DATE-$TO_DATE"
```

### Weekly Reports

Run on a weekly build schedule, e.g. `H 21 * * 1`.

```bash
. /home/jenkins/jenkins_env
export CLUSTER_NAME="StudentEngagementCsvFileTaskWeekly Cluster"
cd $HOME

FROM_DATE=$(date +%Y-%m-%d --date="-7 days")
TO_DATE=$(date +%Y-%m-%d)
NOW=`date +%s`

analytics-configuration/automation/run-automated-task.sh StudentEngagementCsvFileTask --local-scheduler \
  --output-root "$EDXAPP_S3_BUCKET/grades-download/" \
  --marker "$HADOOP_S3_BUCKET/intermediate/student_engagement/$NOW/marker" \
  --interval-type weekly \
  --interval "$FROM_DATE-$TO_DATE"
```
