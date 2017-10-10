Insights/Analytics API Setup
============================

See [AWS Setup](AWS_setup.md) to set up AWS resources and prepare secure configuration.

Shell into the [director instance](AWS_setup.md#director-ec2), launch the virtualenv, and go to the playbooks dir:

```bash
workon edx-configuration
cd configuration/playbooks
```

Playbooks
---------

Create an ansible playbook to deploy Insights and the Analytics API using [`edx/configuration`
roles](https://github.com/edx/configuration/playbooks/roles).  See
[`analytics_sandbox.yml`](resources/playbooks/analytics_sandbox.yml) for an example playbook.

If you are splitting these services across multiple EC2 instances, then you'll need two playbooks, e.g.
[`analytics_insights.yml`](resources/playbooks/analytics_insights.yml) and
[`analytics_api.yml`](resources/playbooks/analytics_api.yml).

Ensure that your playbook(s) are located on your [director instance](../shared/director.md) under `configuration/playbooks`.

Variables and SSH Keys
----------------------

Clone your secure repo (see [Sensitive Data](AWS_setup.md#sensitive-data)) into the home directory.

Update [`vars-analytics.yml`](resources/vars-analytics.yml) to override default variables used in [`edx/configuration`
roles](https://github.com/edx/configuration/playbooks/roles).

If you are splitting these services across multiple EC2 instances, then you'll need to also override
`ANALYTICS_API_NGINX_PORT` and `ANALYTICS_API_ENDPOINT`.

Run Ansible
-----------

You might want to enable logging ansible output into a file.  Just don't forget to clean it up periodically, ansible
only appends to that file (and running multiple tasks result in output mixed).

To log to a file, update `configuration/playbooks/ansible.cfg`:

```yaml
[defaults]
log_path=./ansible.log
```

You may also want to create a screen session to run ansible in, just in case your network drops out during provisioning,
which can take some time. See this [`screen` quick reference](http://aperiodic.net/screen/quick_reference) and the [GNU
`screen` Users Manual](https://www.gnu.org/software/screen/manual/screen.html) for help using `screen`.

Run the [playbook(s) created above](#playbooks) using the following arguments:

* `-i "<analytics-ip>,"`: The internal IP address of your Insights/Analytics API EC2 instance.  Note the trailing comma.
* `-u ubuntu`: User on the analytics EC2 instance with sudo access.
* `-e @/path/to/vars.yml`: Extra variables used to override the defaults.
  Note that analytics ansible script uses some `edxapp`-related variables. There are two ways to supply them:
  * Use two `*-vars.yml` files, and supply them both to ansible (as in example below).  Variables defined in subsequent `-e` arguments take precedence.
  * Merge the two into single `vars.yml` file.
* `--private-key=/path/to/analytics.pem`: The SSH key file used to access your `analytics` instance(s).
* `--vvvv`: Optional verbosity setting.  The more `v`s you give, the more ansible will log.

Example run:

```bash
ansible-playbook -i "1.2.3.4," \
                 -e @/home/ubuntu/secure-config/edxapp-vars.yml -e @/home/ubuntu/secure-config/vars-analytics.yml \
                 -u ubuntu \
                 --private-key=/home/ubuntu/secure-config/analytics.pem \
                 analytics_sandbox.yml
```

Wait for it to complete.

Troubleshooting
---------------

```bash
Compressing...
2016-04-20 10:13:59,565 p=20676 u=ubuntu |  FATAL: all hosts have already failed -- aborting
```

This "error" message is a bit misleading, but about 50-60 lines above it is the actual error message:

```bash
stderr: CommandError: An error occured during rendering /anything/anything/anything_template.html:
Exception in thread "main" java.lang.UnsupportedClassVersionError: com/google/javascript/jscomp/CommandLineRunner
: Unsupported major.minor version 51.0
```

Ansible installs the Java™ 6 (`java-6-openjdk-amd64` package), which is incompatible with the Closure (?) compiler. To
fix this, make sure java-7 is installed, update alternatives to use java 7, manually run failed command on instance,
than restart ansible script:

```bash
ubuntu@director> ssh -i analytics.pem ubuntu@analytics_ip
ubuntu@analytics> sudo apt-get install openjdk-7-jdk -y
ubuntu@analytics> sudo apt-get update-alternatives --config java  # interactive session - choose entry with
java-7-openjdk-amd64
ubuntu@analytics> sudo -Hu insights bash
insights@analytics> cd
insights@analytics> . insights_env
insights@analytics> . venvs/insights/bin/activate
(insights)insights@analytics> cd edx_analytics_dashboard
(insights)insights@analytics> cd edx_analytics_dashboard
(insights)insights@analytics> ./manage.py compress
... wait for it ...
(insights)insights@analytics> Ctrl-D
ubuntu@analytics> Ctrl-D
ubuntu@director> # rerun ansible task
```

OAuth2
======

While the playbook is running, you can create the OAuth2 clients used by the analytics instance.

Insights OAuth2
---------------

Create the OAuth2 client for accessing Insights in the LMS by SSHing to your `edxapp` instance.  You can do this before
your Insights EC2 instance is provisioned.  Just make sure the `INSIGHTS_OAUTH2_KEY` and `INSIGHTS_OAUTH2_SECRET` values
match those specified in your [`vars-analytics.yml`](resources/vars-analytics.yml).

```bash
# ssh to edxapp instance
sudo -Hu edxapp bash
cd
source edxapp_env
cd edx-platform
./manage.py lms --setting=$EDX_PLATFORM_SETTINGS create_oauth2_client \
    <INSIGHTS_BASE_URL_PROTOCOL>://<INSIGHTS_BASE_URL> \
    <INSIGHTS_BASE_URL_PROTOCOL>://<INSIGHTS_BASE_URL>/complete/edx-oidc/ \
    confidential --client_name insights \
    --client_id <INSIGHTS_OAUTH2_KEY> \
    --client_secret <INSIGHTS_OAUTH2_SECRET> \
    --trusted
```

### Analytics Pipeline OAuth2 client

Do this step only if your client requires the Problem Response Reports.

This client is used by the analytics pipeline `ProblemResponseReportWorkflow` task to fetch course list and course
blocks data from the LMS REST API.

Copy the `client_id` and `client_secret` used here into [`analytics-override.cfg`](resources/analytics-override.cfg)
under `[edx-rest-api]`.

Provide a `user` name who has global staff level access to the courses you'll be fetching.

*Note:* Because this client doesn't use OIDC handshaking, the URLs provided are not important.  However, the `user` is.

```bash

# ssh to edxapp instance
sudo -Hu edxapp bash
cd
source edxapp_env
cd edx-platform
./manage.py lms --setting=aws create_oauth2_client \
    http://localhost:9999 \
    http://localhost:9999/complete/edx-oidc/ \
    confidential --client_name analytics-pipeline \
    --client_id <client_id> \
    --client_secret <client_secret> \
    --user <staff_username> \
    --trusted
```

Verify Insights
===============

When ansible finishes, you should be able to go to Insights URL and log in into it using LMS as OAuth2 identity
provider.

Troubleshooting
---------------

Insights settings are located in `/edx/etc/insights.yml` on the Insights EC2 instance. It should contain variables from
your `vars-analytics.yml`.

* No response from Insights at all:
  * Check that you're using correct port
  * Check that port is open in `analytics` Security Group (and Insights EC2 instance has that Security Group assigned)
  * Check HTTP/HTTPS (if using HTTPS, don't forget to set `INSIGHTS_NGINX_SSL_PORT` in `vars-analytics.yml`)
  * Check that Elastic IP is assigned to the correct instance (especially when adding `anayltics-2`, `analytics-3`, etc.)
* Can't log in to Insights - most of such errors are due to broken OAuth2 configuration.
  * Clicking "Login" in Insights takes to 404 page in LMS.
       Most likely LMS OAuth2 provider is disabled. Check that `FEATURES[ENABLE_OAUTH2_PROVIDER]` is set to `true` in
       `/edx/app/edxapp/*.env.vars`.
  * Successfully authenticates to LMS, but some error happens later.
    * In LMS: `invalid_request The requested redirect didn't match the client settings.` - make sure OAuth2 Client is configured with correct Insights endpoint:
    * Go to LMS_URL/admin/oauth2/clients, select the Insights client, and make sure `Redirect` field contains
                [the correct URL](#insights-oauth2), using `http` or `https` as appropriate for your setup.
    * Check `SOCIAL_AUTH_REDIRECT_IS_HTTPS` is set to `true` for HTTPS Insights and to `false` for HTTP
                Insights.
                It is taken from `INSIGHTS_SOCIAL_AUTH_REDIRECT_IS_HTTPS` ansible var.
    * Check `EDXAPP_LMS_BASE_SCHEME` - sets LMS scheme (HTTP/HTTPS). This setting is also used for OAuth2
                authentication, as part of `issuer` string, used by OAuth2 clients (i.e. Insights). LMS OAuth2 provider
                uses actual host, so if redirect to HTTPS is enabled, actual OAuth2 responses will have `issuer` set to
                https://LMS_URL, even if this setting is set to http, causing OAuth2 clients to cancel authentication.
                Recommended value: `https` if LMS uses HTTPS, `http` otherwise.
    * In LMS: `unauthorized_client An unauthorized client tried to access your resources.` - Insights setting
          `SOCIAL_AUTH_EDX_OIDC_KEY` was not found among LMS' OAuth2 Clients' `Client ID`. Check that LMS `Client ID`
          matches `INSIGHTS_OAUTH2_KEY` variable value.
    * In LMS `... request cancelled...` - this happens when LMS can't confirm authenticity of the request, which
          means that `INSIGHTS_OAUTH2_SECRET` Insights setting does not match with `Client Secret` value in LMS OAuth2
          client.
    * In Insights: 500 response and `AuthCanceled: Authentication process cancelled` in
          `/edx/var/log/insights/edx.log` - means that Insights was not able to decrypt LMS response - it
          happens in two cases:
      * Insights setting `SOCIAL_AUTH_EDX_OIDC_SECRET` does not match `Client secret` in LMS
      * Insights setting `SOCIAL_AUTH_EDX_OIDC_ID_TOKEN_DECRYPTION_KEY` does not match
                `SOCIAL_AUTH_EDX_OIDC_SECRET` - should not normally happen, as they are taken from the same variable.
* Insights home shows 500 after logging in, and `/edx/var/log/insights/edx.log` shows something like:

    ```bash
    ProgrammingError: (1146, "Table 'dashboard.soapbox_message' doesn't exist")
    ```
    To fix this, run syncdb as the `insights` user:

    ```bash
    sudo -u insights -Hs
    source ~/insights_env
    cd ~/edx-analytics-dashboard
    ./manage.py migrate --run-syncdb
    ```

    cf [openedx-analytics post](https://groups.google.com/forum/#!msg/openedx-analytics/WkqJwPERf80/WVtu155PBwAJ)
* If the `ImportEnrollmentsIntoMysql` task hasn't run yet, then the home page of Insights may return a 500 error,
  and `/edx/var/log/insights/edx.log` will show something like:

  ```bash
  NotFoundError: Resource http://127.0.0.1:8100/api/v0/course_summaries/ was not found on the API server.
  ```
  However, this only affects the home course list page.  The inner course-specific analytics pages will display fine.
* Even after the `ImportEnrollmentsIntoMysql` task has run, the home page of Insights is still returning a 500 error,
  and `/edx/var/log/insights/edx.log` shows something like:

  ```bash
  ClientError: Resource "course_summaries/" returned status code 500
  ```

  And `/edx/var/log/analytics-api/edx.log` shows something like:

  ```bash
  TypeError: unsupported operand type(s) for +: 'int' and 'NoneType'
  ```

  This issue happens because the analytics pipeline creates tables and fields that the Analytics API accesses, but it
  doesn't create them using the default values that the Analytics API expects.  This should be fixed properly in the
  code someday, but to work around it, run this on the `reports` database:

  ```sql
  mysql> alter table course_meta_summary_enrollment alter passing_users set default 0;
  mysql> update course_meta_summary_enrollment set passing_users=0 where passing_users is Null;
  ```
* There is no data in Insights - that's actually ok, we haven't run any pipeline tasks yet.

Configure Insights
------------------

The Insights application has a number of [waffle feature flags and
switches](https://waffle.readthedocs.io/en/v0.9/types.html) which are disabled by default.  These can be used to disable
new features, so that they can be enabled when and if the data becomes ready.

Feature "flags" can be enabled for specific groups of users using these arguments:

* `--everyone`: Activate flag for all users.
* `--deactivate`: Deactivate flag for all users.
* `--percent=PERCENT`: Roll out the flag for a certain percentage of users.  Takes a number between 0.0 and 100.0
* `--superusers`: Turn on the flag for Django superusers.
* `--staff`: Turn on the flag for Django staff.
* `--authenticated`: Turn on the flag for logged in users.

Run the following command on your Insights instance from within the Insights env:

```bash
sudo -u insights -Hs
source ~/insights_env
cd ~/edx_analytics_dashboard
```

To create and enable a  given feature flag, e.g. to give everyone access to the learner analytics:

```bash
./manage.py waffle_flag display_learner_analytics --everyone --create --settings=analytics_dashboard.settings.production
```

Feature "switches" are either on or off.  Use this command to enable CSV downloads from learner analytics:

```bash
./manage.py waffle_switch enable_learner_download on --create --settings=analytics_dashboard.settings.production
```

To list the current flags and switches, use the `--list` argument:

```bash
~/edx_analytics_dashboard/manage.py waffle_flag --list --settings=analytics_dashboard.settings.production
~/edx_analytics_dashboard/manage.py waffle_switch --list --settings=analytics_dashboard.settings.production
```

We commonly enable these features:

* `enable_course_api` (switch): allows course information to be fetched from the Analytics API.  Requires the Analytics
  API to be running and configured to allow Insights users to authenticate.
* `display_names_for_course_index` (switch): shows the list of available courses as fetched from the Analytics API.
  Also requires the Analytics API.
* `display_course_name_in_nav` (switch): shows course names instead of IDs in GUI.  Also requires the Analytics API.
* `enable_engagement_videos_pages` (switch): shows the video engagement statistics page.
* `display_learner_analytics` (flag): shows the Learner Analytics tab.  Requires the `ModuleEngagementWorkflowTask` to
  be run to populate the charts.
* `enable_learner_download` (switch): shows a "Download CSV" button on the Learner Analytics page.  Requires the
  `display_learner_analytics` flag to be enabled, and its associated tasks to be run.
* `enable_problem_response_download`: shows a "Download CSV" link on the Performance tab.  Enable only if your client
  requires these reports.  Run the `ProblemResponseReportWorkflow` pipeline task to generate reports for download.
