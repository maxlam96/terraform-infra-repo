output "vpc_id" {
  description = "Created VPC ID."
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "Created VPC CIDR block."
  value       = aws_vpc.main.cidr_block
}

output "subnet_ids" {
  description = "Subnet IDs keyed by subnet name."
  value       = { for key, subnet in aws_subnet.this : key => subnet.id }
}

output "subnet_ids_by_tier" {
  description = "Subnet IDs grouped by tier."
  value = {
    for tier in distinct([for subnet in local.effective_subnets : subnet.tier]) :
    tier => [
      for key, subnet in aws_subnet.this :
      subnet.id
      if local.effective_subnets[key].tier == tier
    ]
  }
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value = [
    for key, subnet in aws_subnet.this :
    subnet.id
    if local.effective_subnets[key].tier == "public"
  ]
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value = [
    for key, subnet in aws_subnet.this :
    subnet.id
    if local.effective_subnets[key].tier == "private"
  ]
}

output "database_subnet_ids" {
  description = "Database subnet IDs."
  value = [
    for key, subnet in aws_subnet.this :
    subnet.id
    if local.effective_subnets[key].tier == "database"
  ]
}

output "intra_subnet_ids" {
  description = "Intra subnet IDs."
  value = [
    for key, subnet in aws_subnet.this :
    subnet.id
    if local.effective_subnets[key].tier == "intra"
  ]
}

output "route_table_ids" {
  description = "Route table IDs keyed by subnet name."
  value       = { for key, route_table in aws_route_table.this : key => route_table.id }
}

output "internet_gateway_id" {
  description = "Internet gateway ID when enabled."
  value       = var.enable_internet_gateway ? aws_internet_gateway.main[0].id : null
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs keyed by public subnet name."
  value       = { for key, nat_gateway in aws_nat_gateway.this : key => nat_gateway.id }
}

output "nat_eip_ids" {
  description = "NAT gateway Elastic IP allocation IDs keyed by public subnet name."
  value       = { for key, eip in aws_eip.nat : key => eip.id }
}

output "vpn_gateway_id" {
  description = "Virtual private gateway ID when enabled."
  value       = var.enable_vpn_gateway ? aws_vpn_gateway.this[0].id : null
}

output "customer_gateway_ids" {
  description = "Customer gateway IDs keyed by name."
  value       = { for key, gateway in aws_customer_gateway.this : key => gateway.id }
}

output "vpn_connection_ids" {
  description = "VPN connection IDs keyed by name."
  value       = { for key, connection in aws_vpn_connection.this : key => connection.id }
}

output "direct_connect_gateway_id" {
  description = "Direct Connect Gateway ID when enabled."
  value       = var.enable_direct_connect_gateway ? aws_dx_gateway.this[0].id : null
}

output "direct_connect_gateway_association_id" {
  description = "Direct Connect Gateway association ID when enabled."
  value       = var.enable_direct_connect_gateway ? aws_dx_gateway_association.this[0].id : null
}

output "transit_gateway_vpc_attachment_id" {
  description = "Transit Gateway VPC attachment ID when enabled."
  value       = var.enable_transit_gateway_attachment ? aws_ec2_transit_gateway_vpc_attachment.this[0].id : null
}

output "vpc_peering_connection_ids" {
  description = "Created VPC peering connection IDs keyed by name."
  value       = { for key, peering in aws_vpc_peering_connection.this : key => peering.id }
}

output "vpc_peering_accepter_ids" {
  description = "Accepted VPC peering connection IDs keyed by name."
  value       = { for key, accepter in aws_vpc_peering_connection_accepter.this : key => accepter.id }
}

output "network_acl_ids" {
  description = "Custom network ACL IDs keyed by name."
  value       = { for key, acl in aws_network_acl.this : key => acl.id }
}

output "database_subnet_group_name" {
  description = "RDS database subnet group name when enabled."
  value       = var.create_database_subnet_group ? aws_db_subnet_group.database[0].name : null
}

output "elasticache_subnet_group_name" {
  description = "ElastiCache subnet group name when enabled."
  value       = var.create_elasticache_subnet_group ? aws_elasticache_subnet_group.database[0].name : null
}

output "redshift_subnet_group_name" {
  description = "Redshift subnet group name when enabled."
  value       = var.create_redshift_subnet_group ? aws_redshift_subnet_group.database[0].name : null
}

output "vpc_endpoint_security_group_id" {
  description = "Security group ID used by interface VPC endpoints when enabled."
  value       = var.enable_vpc_endpoints ? aws_security_group.vpc_endpoints[0].id : null
}
