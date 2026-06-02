aws_region  = "ap-southeast-1"
environment = "production"
project     = "floci-vpc-lab"
owner       = "platform"

name = "floci-vpc-lab-production"
cidr = "10.50.0.0/16"

azs = [
  "ap-southeast-1a",
  "ap-southeast-1b",
  "ap-southeast-1c"
]

public_subnets = [
  "10.50.1.0/24",
  "10.50.2.0/24",
  "10.50.3.0/24"
]

private_subnets = [
  "10.50.11.0/24",
  "10.50.12.0/24",
  "10.50.13.0/24"
]

database_subnets = [
  "10.50.21.0/24",
  "10.50.22.0/24",
  "10.50.23.0/24"
]

enable_nat_gateway   = true
single_nat_gateway   = false
enable_vpn_gateway   = true
enable_dhcp_options  = true
enable_vpc_endpoints = true
enable_vpc_flow_logs = true

dhcp_options_domain_name         = "ap-southeast-1.compute.internal"
dhcp_options_domain_name_servers = ["AmazonProvidedDNS"]

manage_default_security_group = true
manage_default_network_acl    = true
manage_default_route_table    = true

create_database_subnet_group    = true
create_elasticache_subnet_group = true
create_redshift_subnet_group    = true

gateway_endpoint_subnet_keys = [
  "private-a",
  "private-b",
  "private-c",
  "database-a",
  "database-b",
  "database-c"
]

interface_endpoint_subnet_keys = [
  "private-a",
  "private-b",
  "private-c"
]
