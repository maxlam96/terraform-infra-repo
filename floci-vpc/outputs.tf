output "vpc_id" {
  description = "Created VPC ID."
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs keyed by subnet name."
  value       = module.vpc.subnet_ids
}

output "route_table_ids" {
  description = "Route table IDs keyed by subnet name."
  value       = module.vpc.route_table_ids
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs keyed by public subnet name."
  value       = module.vpc.nat_gateway_ids
}

output "vpn_gateway_id" {
  description = "Virtual private gateway ID when enabled."
  value       = module.vpc.vpn_gateway_id
}

output "database_subnet_group_name" {
  description = "RDS database subnet group name when enabled."
  value       = module.vpc.database_subnet_group_name
}

output "elasticache_subnet_group_name" {
  description = "ElastiCache subnet group name when enabled."
  value       = module.vpc.elasticache_subnet_group_name
}

output "redshift_subnet_group_name" {
  description = "Redshift subnet group name when enabled."
  value       = module.vpc.redshift_subnet_group_name
}

output "vpc_peering_connection_ids" {
  description = "Created VPC peering connection IDs keyed by name."
  value       = module.vpc.vpc_peering_connection_ids
}

output "vpc_peering_accepter_ids" {
  description = "Accepted VPC peering connection IDs keyed by name."
  value       = module.vpc.vpc_peering_accepter_ids
}

output "public_subnet_id" {
  description = "Public subnet ID kept for Jenkins lab compatibility."
  value       = module.vpc.subnet_ids["public-a"]
}

output "private_subnet_id" {
  description = "Private application subnet ID kept for Jenkins lab compatibility."
  value       = module.vpc.subnet_ids["private-a"]
}

output "database_subnet_id" {
  description = "Database subnet ID kept for Jenkins lab compatibility."
  value       = module.vpc.subnet_ids["database-a"]
}
