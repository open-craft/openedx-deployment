output "rds_host_name" {
  value = module.sql.mysql_host_name
}

output "elasticsearch_learners_host" {
  value = module.analytics.elasticsearch_host
}

output "analytics_instance_private_ips" {
  value = module.analytics.analytics_instance_private_ips
}

output "analytics_instance_public_ips" {
  value = module.analytics.analytics_instance_public_ips
}
