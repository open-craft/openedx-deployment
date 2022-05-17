# Open edX AWS Production Deployment and Upgrades

--------------------------

⚠️ Out of date
=============

**A newer version of this documentation is available at [https://doc.opencraft.com/aws-openedx/aws-deployment/](https://doc.opencraft.com/aws-openedx/aws-deployment/)**

A copy is below for historical purposes only.

--------------------------

Deploying to an AWS instance isn't totally automated. You'll need to log in to the AWS panel, prepare servers, and then SSH to the instance.
The longest part of the deployment process is waiting for an `ansible` playbook which does all the provisioning.

Some of the components we use in Amazon are:
- We always create *two* instances: the one to be provisioned, and a proxy one, called [director](../shared/director.md), that we use as proxy to connect to the final one.
- We store the data in an [RDS](../shared/RDS.md) instance, that we create and backup separately
- At the end of the deployment process, we switch something to point to the final instance; instances without a load balancer would change a DNS register to point to the IP, while instances with load balancer would switch what Amazon calls [Elastic IP](../shared/Elastic_IP.md) to point to the new server IP

This article is about deploying LMS/CMS.
See also how to setup [Analytics in AWS](../analytics/AWS_setup.md).

## Initial deployment
Similar to upgrades (see below).

## How to upgrade an instance

The basics are:

1. set up `vars.yml` in some directory or repository. Review the variables inside `vars.yml` (including private information like users/passwords). These variables will override the default variables found in `edx-configuration`
1. create a new EC2 instance
1. backup [RDS](../shared/RDS.md)
1. provision the new server by running `ansible-playbook`:
   - do it from [director](../shared/director.md)
   - use the [edx_sandbox.yml](https://github.com/edx/configuration/blob/master/playbooks/edx_sandbox.yml) playbook but with the `aws` role added
   - for example: `ansible-playbook -vvv --user=ubuntu --private-key=../../edu-private/edxapp.pem --extra-vars=@"../../edu-private/vars.yml" edx_sandbox.yml -i "172.31.72.3,"`
1. wait for provisioning to complete
1. test the new service
1. change the [elastic IP](../shared/Elastic_IP.md) or DNS record to point to the new instance
1. stop the old instance

Note that we don't modify the old instance, or stop any service running there. The deployment happens in a new instance and later we switch to it. For a short time, both instances could be accessing the same databases, but it's usually safe.

More difficult upgrades might require two phases, e.g. from Ficus.3 to Ficus.4 and then from Ficus.4 to Ginkgo.1.
