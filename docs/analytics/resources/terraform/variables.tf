# TODO: update all of these with the specific details for your client's setup.
locals {
  customer_name = "client"
  environment = "analytics"
  aws_region = "us-east-1"
  aws_profile = "client-analytics"

  edxapp_s3_grade_bucket_id = "client-prod-edxapp-storage"
  edxapp_s3_grade_bucket_arn = "arn:aws:s3:::client-prod-edxapp-storage"
  edxapp_s3_grade_bucket_user_arn = "arn:aws:iam::1234567890:user/client-prod-edxapp-s3"

  # Locate an appropriate AMI for your AWS region and VM type:
  # https://cloud-images.ubuntu.com/locator/
  analytics_image_id = "ami-abcdef0123456789a"
  analytics_instance_type = "t2.medium"
  analytics_instance_profile = "edx-analytics-edx"
  analytics_key_pair_name = "edx-analytics"

  # If you use more than one instance to host Insights/Analytics API/Jenkins,
  # be sure to only run the Jenkins analytics pipeline on one of them.
  analytics_number_of_instances = 1
  analytics_instance_iteration = 1

  analytics_mysql_allocated_storage = "5"
  analytics_mysql_root_password = "********************"
  analytics_mysql_root_username = "********"
  analytics_mysql_instance_class = "db.t2.medium"

  emr_rds_security_group_id = "sg-abcdf0123456789ab"

  hosted_zone_domain = "client.domain.tld"
  director_security_group_id = "sg-abcdef0123456789a"
}
