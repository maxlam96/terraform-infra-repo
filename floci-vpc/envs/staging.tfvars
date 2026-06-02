aws_region  = "us-east-1"
environment = "staging"
project     = "floci-vpc-lab"
# owner       = "platform"

name = "floci-vpc-lab-staging"
cidr = "10.40.0.0/16"

azs              = ["us-east-1a"]
public_subnets   = ["10.40.1.0/24"]
private_subnets  = ["10.40.2.0/24"]
database_subnets = ["10.40.3.0/24"]

# Floci currently does not emulate these AWS APIs; production.tfvars keeps them enabled.
enable_nat_gateway   = false
enable_vpc_endpoints = false
enable_vpc_flow_logs = false

enable_vpn_gateway                   = false
amazon_side_asn                      = 64512
propagate_private_route_tables_vgw   = false
enable_direct_connect_gateway        = false
direct_connect_gateway_asn           = 64513
direct_connect_allowed_prefixes      = ["192.168.10.0/24"]
direct_connect_associated_gateway_id = null

customer_gateways = {}

vpn_connections = {}
