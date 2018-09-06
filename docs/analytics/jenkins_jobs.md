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

Configuring Jenkins jobs
------------------------

To add a new Jenkins job, you can:

* [Create the job from scratch](#create-new-jenkins-job).
* [Clone an existing job](#clone-existing-jenkins-job) and modify it.
* [Import an old job's config.xml](#import-jenkins-job-configxml).

Create new Jenkins job
----------------------

To create job, authenticate to Jenkins, than go to main page.

* Click "New Item" in the left sidebar.
* Set the task name to be the insights domain, followed by a recognizable name that uniquely identifies the task (e.g. "insights.example.com Module Engagement"). Having the insights domain prepended to the task name will help recipients of the error emails to quickly identify the source analytics instance of any future task failure alerts.
* If this is the first task created, select "Build a free-style software project"
  For subsequent tasks, you can [Copy from existing item](#clone-existing-jenkins-job) instead, which saves a lot of
  steps.

* `Project name`: set automatically from previous step
* `Description`: provide appropriate description
* `Discard Old Builds`: enable
  * `Strategy`: Log Rotation
  * `Days to keep builds`: (leave blank)
  * `Max # of builds to keep`: 50
  * `Advanced: Days to keep artifacts`: (leave blank)
  * `Advanced: Max # of builds to keep with artifacts`: 50
* `Github project`: (leave blank)
* `Job Notifications`: use section defaults
* `Advanced Project Options`: use section defaults
* `Source Code Management`: `None`
* `Build Triggers`: `Build Periodically`
  * `Schedule`: e.g., `H X * * *`, see [Commands](#commands) for suggested schedules.
    * `X` is an hour to run task (i.e. with X=19 task will run at 19:00 daily)
    * `H` is a Jenkins hash used to spread the load.

    It makes sense to try to reduce even load on the server by running tasks throughout the day, i.e. not put them all
    to `0 0 * * *`, or even `H H * * *` (`H` is a hash, so it might put some tasks closely together).

    Refer to Jenkins help should the need for a more sophisticated schedule arise.
* `Build Environment`
    * `Abort the build if it's stuck`: enable
        * `Time-out strategy`: `Absolute`
        * `Timeout Minutes`: `300`
        * Click `Add Action` and add `Fail the Build`.
    * `SSH Agent`: enable
      * `Credentials`: `Specific credentials`: hadoop

      This allows Jenkins to ssh to the EMR servers via the shell command.

      Select the 'hadoop' ssh access key created by ansible.

      If the ssh credentials were not configured via ansible you can manually create a key here by clicking       the `Add Key` button.

        * Kind: SSH username with private key
        * Scope: Global
        * Username: `hadoop`
        * Private key: paste the analytics private key file contents directly, or copy the file to the analytics
          instance and point to the path.
        * Passphrase: Leave empty for AWS-issued private key files.
        * Description: ssh credential file
* `Build`
    * `Add Step` -> `Execute Shell`.
        * Fill in `Command` field with shell script to run. See [Commands](#commands) for details.
    * `Post build actions` -> `Add post build task`
        * `Log text`: `Traceback`
        * `Script`: `exit 1`
        * `Run script only if all previous steps were successful`: `yes`
        * `Escalate script execution status to job status`: `yes`
    * `Post build actions` -> `Add post build action` -> `Email Notification`
        * `Recipients` - an alert email address, e.g. `ops@example.com`
        * `Send e-mail for every unstable build`: `yes`
        * `Send separate e-mails to individuals who broke the build`: `no`
* Finally, click `Save`

Clone existing Jenkins job
--------------------------

Once you have a [Jenkins job created](#create-new-jenkins-job), you can clone it into a new job and modify it.

To do this:

* Click "New Item" in the left sidebar.
* Set the task name to be the insights domain, followed by a recognizable name that uniquely identifies the task (e.g. "insights.example.com Module Engagement"). Having the insights domain prepended to the task name will help recipients of the error emails to quickly identify the source analytics instance of any future task failure alerts.
* Select "Copy from existing item" and select the existing task to clone from.
* Click "Ok" to create the cloned item.
* Modify the settings that differ (e.g. name, description, schedule crontab, command), and "Save".

Import Jenkins job config.xml
-----------------------------

To perform this step reliably, you must be running with the same (or similar) version of Jenkins that the `config.xml`
file was created with, otherwise strange problems may arise (cf https://stackoverflow.com/q/8424228/4302112).

For example, to get a job's `config.xml`:

```bash
curl -X GET \
     -o AnalyticsTaskName_config.xml \
     'http://orig.jenkins.url/job/insights.example.com%20AnalyticsTaskName/config.xml'
```

To import a `config.xml` file:

```bash
cat AnalyticsTaskName_config.xml | curl -X POST \
     --header "Content-Type: application/xml" \
     --data-binary @- \
     'http://new.jenkins.url/createItem?name=insights.example.com%20AnalyticsTaskName'
```

# Commands

These example commands rely heavily on environment variables defined in [`jenkins_env`](resources/jenkins_env).  See
[Jenkins Env and Configuration Overrides](jenkins.md#jenkins-env-and-configuration-overrides) for a
discussion of these environment variables.

One can do without a `jenkins_env` file by omitting the `. /home/jenkins/jenkins_env` command from the shell script
body, and list the environment variables in the actual shell command inline.

Note that the build schedules can and should be adjusted as needed. Depending on the number and size of tracking logs, different jobs can take a differing amount of time. Some jobs can conflict while editing the s3 buckets, causing failures due to race conditions. If this kind of contention occurs, changing the schedule for jobs is perfectly fine and can often fix the problem.

## Answer Distribution

In edx docs: [Performance (graded and ungraded)](http://edx-analytics-pipeline-reference.readthedocs.io/en/latest/running_tasks.html#performance-graded-and-ungraded)

Run on periodic build schedule, e.g. `H 7 * * *`.

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
    --src "'[\"$TRACKING_LOGS_S3_BUCKET/logs/tracking\"]'" \
    --dest "$ANSWER_DIST_S3_BUCKET" \
    --name AnswerDistributionWorkflow \
    --output-root $HADOOP_S3_BUCKET/grading_reports/ \
    --include "'[\"*tracking.log*.gz\"]'" \
    --manifest "$ANSWER_DIST_S3_BUCKET/manifest.txt" \
    --base-input-format "org.edx.hadoop.input.ManifestTextInputFormat" \
    --lib-jar "'[\"$TASK_CONFIGURATION_S3_BUCKET/edx-analytics-hadoop-util.jar\"]'" \
    --n-reduce-tasks $NUM_REDUCE_TASKS \
    --marker "$ANSWER_DIST_S3_BUCKET/marker"
```

## Enrollments Total, Enrollments by Gender, Age, Education

In edx docs: [Enrollment](http://edx-analytics-pipeline-reference.readthedocs.io/en/latest/running_tasks.html#enrollment)

### Bootstrap history task

Before running the daily incremental enrollment task, below, you should first run the history task that loads historical enrollment events.

In edx docs: [Enrollment History Task](http://edx-analytics-pipeline-reference.readthedocs.io/en/latest/running_tasks.html#history-task)

Imports enrollments data; runs daily.

Run on periodic build schedule, e.g. `H 0 * * *`.

```bash
. /home/jenkins/jenkins_env
export CLUSTER_NAME="ImportEnrollmentsIntoMysql Cluster"
cd $HOME

TO_DATE=`date +%Y-%m-%d`
analytics-configuration/automation/run-automated-task.sh ImportEnrollmentsIntoMysql \
    --local-scheduler \
    --interval "$START_DATE-$TO_DATE" \
    --n-reduce-tasks $NUM_REDUCE_TASKS
```

## Enrollments By Country

In edx docs: [Geography](http://edx-analytics-pipeline-reference.readthedocs.io/en/latest/running_tasks.html#geography)

### Bootstrap history task

Before running the daily incremental enrollment by country task, below, you should first run the history task that loads historical events.

In edx docs: [Enrollments By Country History task](http://edx-analytics-pipeline-reference.readthedocs.io/en/latest/running_tasks.html#id6)

Enrollments by geolocation; runs daily.

Run on periodic build schedule, e.g. `H 5 * * *`.

```bash
. /home/jenkins/jenkins_env
export CLUSTER_NAME="InsertToMysqlLastCountryPerCourseTask Cluster"
cd $HOME

NOW=`date +%s`
analytics-configuration/automation/run-automated-task.sh InsertToMysqlLastCountryPerCourseTask \
    --local-scheduler \
    --n-reduce-tasks $NUM_REDUCE_TASKS \
    --overwrite
```

## Course Activity

In edx docs: [Engagement](http://edx-analytics-pipeline-reference.readthedocs.io/en/latest/running_tasks.html#engagement)

Weekly course activity; runs every Monday.

Run on periodic build schedule, e.g. `H 1 * * 1`.

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

In edx docs: [Learner analytics](http://edx-analytics-pipeline-reference.readthedocs.io/en/latest/running_tasks.html#learner-analytics)

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

In edx docs: [ModuleEngagementWorkflowTask](http://edx-analytics-pipeline-reference.readthedocs.io/en/latest/running_tasks.html#id13)

Weekly course module engagement data stored in an ElasticSearch index; runs daily.

Run on periodic build schedule, e.g. `H 3 * * *`.

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

In edx docs: [Video](http://edx-analytics-pipeline-reference.readthedocs.io/en/latest/running_tasks.html#video)

Tracks video interactions; runs daily.

Run on periodic build schedule, e.g. `H 9 * * *`.

```bash
. /home/jenkins/jenkins_env
export CLUSTER_NAME="InsertToMysqlAllVideoTask Cluster"
cd $HOME

TO_DATE=`date +%Y-%m-%d`
analytics-configuration/automation/run-automated-task.sh InsertToMysqlAllVideoTask --local-scheduler \
  --interval "$START_DATE-$TO_DATE" \
  --n-reduce-tasks $NUM_REDUCE_TASKS
```

## Student Engagement

### Daily Reports

In edx docs: [StudentEngagementCsvFileTask](http://edx-analytics-pipeline-reference.readthedocs.io/en/latest/all.html#edx.analytics.tasks.data_api.student_engagement.StudentEngagementCsvFileTask)

Run on a daily build schedule, e.g. `H 11 * * *`.

Run this task only if your client requires daily Student Engagement reports.

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

In edx docs: [StudentEngagementCsvFileTask](http://edx-analytics-pipeline-reference.readthedocs.io/en/latest/all.html#edx.analytics.tasks.data_api.student_engagement.StudentEngagementCsvFileTask)

Run on a weekly build schedule, e.g. `H 13 * * 1`.

Run this task only if your client requires weekly Student Engagement reports.

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

## Problem Response Reports

In edx docs: [ProblemResponseReportWorkflow](http://edx-analytics-pipeline-reference.readthedocs.io/en/latest/workflow_entry_point.html#edx.analytics.tasks.insights.problem_response.ProblemResponseReportWorkflow)

Generates learners' problem responses reports; runs daily.

Run this task only if your client requires the Problem Response Reports.  Requires the [Analytics API Reports S3
bucket](AWS_setup.md#analytics-api-reports), and the [Insights `enable_problem_response_download` waffle flag
enabled](insights.md#configure-insights).

If Course Block data is available, then it is merged into the generated reports.

Run on periodic build schedule, e.g. ` H 20 * * * `.

Note: HKS epodX wanted theirs to run hourly, so for them we use: ` H * * * * `.
And we add this to [analytics-override.cfg](resources/analytics-override.cfg), to allow hourly partitions:

    [problem-response]
    partition_format = %Y-%m-%dT%H

Note that it's just the Problem Response data that is re-generated hourly; the Course Blocks and Course List data is
still configured to use the default daily partition.

We use "midnight tomorrow" as the interval end, so that records gathered today will be included immediately in the
generated reports.

Shell build step:

```
. /home/jenkins/jenkins_env
export CLUSTER_NAME="ProblemResponseReportWorkflow Cluster"
cd $HOME

TOMORROW=`date --date="tomorrow" +%Y-%m-%d`

analytics-configuration/automation/run-automated-task.sh ProblemResponseReportWorkflow \
    --local-scheduler \
    --marker $HADOOP_S3_BUCKET/intermediate/problem_response/marker`date +%s` \
    --interval-end "$TOMORROW" \
    --overwrite \
    --n-reduce-tasks $NUM_REDUCE_TASKS
```

