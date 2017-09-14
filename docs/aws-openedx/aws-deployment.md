# openEdx AWS Production Deployment and Upgrades

In contrast to OCIM updates, which are automated through a control panel, AWS updates are more manual and we have to actually log in to the AWS panel and SSH to the instance.
Apart from this, the main part of the deployment process is an `ansible` playbook which does all the provisioning automatically.

Some of the components we use in Amazon are:
- We always create *two* instances: the one to be provisioned, and a proxy one, called [director](../shared/director.md), that we use as proxy to connect to the final one.
- We store the data in an [RDS](../shared/RDS.md) instance, that we create and backup separately
- At the end of the deployment process, we switch an IP to point to the final instance; in Amazon it's called [Elastic IP](../shared/Elastic_IP.md)

This article is about deploying LMS/CMS.
See also how to setup [Analytics in AWS](../analytics/AWS_setup.md).

## Initial deployment
Similar to upgrades (see below).

## How to upgrade an instance

The basics are:

1. set up `vars.yml` in `edx-configuration`
1. create a new instance
1. backup [RDS](../shared/RDS.md)
1. run `ansible-playbook` from [director](../shared/director.md)
1. wait
1. test
1. change the [elastic IP](../shared/Elastic_IP.md) to point to the new instance
1. stop the old instance

Note that we don't upgrade any program in the old instance, nor do we stop programs. The deployment happens in a new instance and later we switch to it. For a short time, both instances could be accessing the same databases, but it's usually safe.

More difficult upgrades might require two phases, e.g. from Ficus.3 to Ficus.4 and then from Ficus.4 to Ginkgo.1.

For the moment, it can be instructive to read stories of past upgrades:

- [Lumerical, Sept 2017: Ficus.3 to Ficus.4 and then to Ginkgo.1](https://docs.google.com/document/d/1R4_gm1WjwDCpNAddDOBaFEaKM4QO-78jFucap7ul6OA/edit#heading=h.4bpi03oynxtd)
