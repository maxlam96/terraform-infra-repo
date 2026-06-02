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

enable_nat_gateway   = true
enable_vpc_endpoints = true
enable_vpc_flow_logs = true

enable_vpn_gateway                   = true
amazon_side_asn                      = 64512
propagate_private_route_tables_vgw   = true
enable_direct_connect_gateway        = false
direct_connect_gateway_asn           = 64513
direct_connect_allowed_prefixes      = ["192.168.10.0/24"]
direct_connect_associated_gateway_id = null

customer_gateways = {
  branch_primary = {
    bgp_asn    = 65010
    ip_address = "203.0.113.10"
    tags = {
      ConnectivityRole = "onprem-primary-dx-backup-vpn"
    }
  }
}

vpn_connections = {
  branch_backup = {
    customer_gateway_key = "branch_primary"
    static_routes_only   = false
    tunnel1_inside_cidr  = "169.254.21.0/30"
    tunnel2_inside_cidr  = "169.254.22.0/30"
    tags = {
      ConnectivityRole = "ipsec-backup"
      RoutingMode      = "bgp"
      PrimaryPath      = "direct-connect"
      BackupPath       = "ipsec-vpn"
    }
  }
}
