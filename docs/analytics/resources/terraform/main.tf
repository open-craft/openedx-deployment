terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.7"
    }
  }
}
provider "aws" {
  region = local.aws_region
  profile = local.aws_profile
}

module "analytics" {
  source = "git@github.com:open-craft/terraform-scripts.git//modules/services/analytics?ref=v1.4.1"
  analytics_image_id = local.analytics_image_id
  analytics_instance_type = local.analytics_instance_type
  analytics_key_pair_name = local.analytics_key_pair_name
  customer_name = local.customer_name
  director_security_group_id = local.director_security_group_id
  emr_master_security_group_description = "Master group for Elastic MapReduce"
  emr_slave_security_group_description = "Slave group for Elastic MapReduce"
  edxapp_s3_grade_bucket_id = local.edxapp_s3_grade_bucket_id
  edxapp_s3_grade_bucket_arn = local.edxapp_s3_grade_bucket_arn
  edxapp_s3_grade_user_arn = local.edxapp_s3_grade_bucket_user_arn
  environment = local.environment
  hosted_zone_domain = local.hosted_zone_domain

  number_of_instances = local.analytics_number_of_instances
  instance_iteration = local.analytics_instance_iteration
}

module "sql" {
  source = "git@github.com:open-craft/terraform-scripts.git//modules/services/sql?ref=v1.4.0"

  customer_name = local.customer_name
  environment = local.environment

  instance_class = local.analytics_mysql_instance_class
  edxapp_security_group_id = module.analytics.analytics_security_group_id
  allocated_storage = local.analytics_mysql_allocated_storage

  database_root_password = local.analytics_mysql_root_password
  database_root_username = local.analytics_mysql_root_username

  extra_security_group_ids = [module.analytics.emr_rds_security_group_id]
}
