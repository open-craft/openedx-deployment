# OpenStack Production Deployment (Proposal)

edX does not officially provide any supported method for deploying a production-grade instance of Open edX. However, the following *proposed* method for setting up a production-grade instance on OpenStack is available to the community, and recommended by OpenCraft. For context, this method of deployment is used in production for over 100 production instances of Open edX on [OpenCraft's hosting platform](http://opencraft.com/hosting/).

To deploy to Amazon Web Services, see [AWS deployment](../aws-openedx/aws-deployment.md).

## Features of this Deployment Method
With this method, you'll get an instance of Open edX that's ready to handle production traffic and which follows well-established best practices for deployments.
 
Details:

* Uses the latest stable Open edX release (Ficus)
* Can be scaled to a multi-VM setup to handle higher traffic levels
* Uses ansible for automated, repeatable provisioning of VMs
* Separates state (user data, course data, etc.) from the app servers (LMS, Studio, etc.)
* Allows most updates and upgrades to be completed without any downtime
* Fully open-source stack
* Does not currently support ecommerce, course discovery, or Insights
 
Requirements

* In order to use this deployment method, you will need:
* An OpenStack cloud provider (Juno release or newer) including Compute (Nova) and Block Storage (Swift). A provider that supports Neutron networking and offers load balancing as a service (LBaaS) is highly recommended.
  - Public cloud providers are listed in the [OpenStack Marketplace](https://www.openstack.org/marketplace/public-clouds/).
  - At a minimum, you will need a VM with 4 GB of RAM
* A MySQL server/cluster running MySQL version 5.6 or newer
* A MongoDB server/cluster running MongoDB version 2.6, 3.0, or 3.2
* A VM running RabbitMQ
* A VM running ElasticSearch version 0.90.13 (not any newer version) - may be installed on the same VM as RabbitMQ
* An SSL certificate for each of the domains (typically there are three: www.example.com, studio.example.com, preview.example.com). We recommend using Let's Encrypt for free SSL certificates.
 
As these are standard open source services, **the installation, configuration, and operation of these database servers is left to your operations team**, and would not be supported by OpenCraft nor edX. However, ansible playbooks which may be used to set up most of these services are provided at https://github.com/edx/configuration/tree/master/playbooks (edX) and https://github.com/open-craft/deployment-deploy-databases (OpenCraft).
 
Additional notes:
* All of the databases and services like RabbitMQ and ElasticSearch should be firewalled off from the public internet.
* Be sure to implement some sort of regular backup for the data in MySQL, MongoDB, and Swift.


## How to deploy for the first time
1. Provision an OpenStack VM that runs Ubuntu 16.04 and has at least 4 GB of RAM. Ensure that ports 22, 80, and 443 are open to the internet.
1. Provision a Swift container
1. Set up MySQL:
   1. Provision five MySQL databases:
       - edxapp
       - xqueue
       - edxapp_csmh
       - edx_notes_api
       - notifier
   1. For each MySQL database, create a username and password with read-write access to the database (for best security, do not allow these users to have schema change permission)
   1. Create two global users with access to all databases: one, a "migration" user with schema change permission on all databases, and one "read only" user with no change/write permissions.
1. Set up MongoDB: Create two databases - one for courseware and one for forum posts. Create a separate username and password for each database.
1. Set up RabbitMQ: Create a username+password for "celery" and another username+password for "xqueue".
1. Set up ElasticSearch as listed in the requirements section above.
1. Create a private git repository (we recommend using GitHub or GitLab) with a name like "sitename-vars" where sitename is the name of your new Open edX site
1. In that new repository, create a vars.yml file using [this template](https://github.com/open-craft/opencraft/pull/204) as a template
1. Go through `vars.yml` and customize each variable to match your planned deployment. The comments included in the file offer an explanation of what each setting does.
1. Set up a "director" VM following [these instructions](../shared/director/).
1. Run ansible to provision the instance using [the edx-stateless.yml playbook](https://github.com/edx/configuration/blob/master/playbooks/edx-stateless.yml):
   ```
   ansible-playbook -i 1.2.3.4 -e@../path/to/sitename-vars.yml -u ubuntu edx-stateless.yml
   ```
   Where 1.2.3.4 is the IP of the VM provisioned in step 1.
1. Update /etc/hosts to point to the new instance, and test it
1. Update the DNS or OpenStack LBaaS to point to the new VM
1. Create a user account
1. SSH in to the instance and give that account admin permissions
   1. `sudo -Hu edxapp bash`
   1. `cd && . edxapp_env  && . ./venvs/edxapp/bin/activate && cd edx-platform/`
   1. `from django.contribu.auth.models import User`
   1. `u = User.objects.get(email='your_email@example.com')`
   1. `u.is_staff = True`
   1. `u.is_superuser = True`
   1. `u.save()`
1. What now? See http://docs.edx.org/ for documentation about configuration and usage of your new instance.


## How to deploy an update
1. Provision a brand new OpenStack VM similar to the VM used for the initial deployment.
1. Update `sitename-vars.yml` as desired
   1. For example, if you are upgrading to a new named release of Open edX, change the `OPENEDX_RELEASE` variable from "open-release/ficus.master" to the git branch name of the new release (e.g. "open-release/ginkgo.master", "open-release/hawthorn.master" etc.)
1. `cd ~/configuration/playbooks`
1. `source ~/mysite-deploy-ansible/bin/activate`
1. Run ansible to provision the instance using the edx-stateless.yml playbook:
   ```
   ansible-playbook -i 1.2.3.4 -e@../path/to/sitename-vars.yml -u ubuntu edx-stateless.yml
   ```
   Where 1.2.3.4 is the IP of the VM provisioned in step 1.
1. Update `/etc/hosts` to point to the new instance, and test it
1. Update the DNS or OpenStack LBaaS to point to the new VM instead of the old one.
 

## How to get support (Proposal)
Please post on [the openedx-ops mailing list](https://www.google.com/url?q=https://groups.google.com/forum/%23!forum/openedx-ops&sa=D&ust=1493711786670000&usg=AFQjCNGzXWqTVJOdP4hySmnSd_wDdC2q9w) and include "(OpenCraft OpenStack deployment)" at the end of your subject line. It will increase the chances to get help with any of the following issues, provided that they correspond to the exact setup described above:

* Problems encountered provisioning an instance using the edx-stateless playbook
* Problems encountered when updating/upgrading an instance
* Advice on configuring/sizing a deployment
 
Note that the subject tag mentioned above should not be used for problems related to:

* Creating an OpenStack account or provisioning virtual machines
* Setting up databases or other services listed in the "requirements" section
* Using Open edX once it has been set up
For these topics, follow the regular methods for [getting help](https://open.edx.org/getting-help).
