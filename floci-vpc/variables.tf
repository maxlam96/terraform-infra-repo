variable "aws_region" {
  description = "AWS-compatible region used by Floci."
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Environment tag and policy context."
  type        = string
  default     = "staging"
}

variable "floci_endpoint" {
  description = "Remote Floci AWS-compatible endpoint."
  type        = string
  default     = "http://192.168.251.1:4566"
}

variable "project" {
  description = "Project name used in names and tags."
  type        = string
  default     = "floci-vpc-lab"
}

variable "name" {
  description = "VPC name prefix. This follows the terraform-aws-modules/vpc style."
  type        = string
  default     = null
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "platform"
}

variable "tags" {
  description = "Additional tags merged into every supported resource."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "cidr" {
  description = "CIDR block for the VPC. This follows the terraform-aws-modules/vpc style."
  type        = string
  default     = null
}

variable "ipv4_ipam_pool_id" {
  description = "IPv4 IPAM pool ID to allocate the VPC CIDR from."
  type        = string
  default     = null
}

variable "ipv4_netmask_length" {
  description = "Netmask length for IPv4 IPAM allocation."
  type        = number
  default     = null
}

variable "enable_ipv6" {
  description = "Assign an Amazon-provided IPv6 CIDR block to the VPC."
  type        = bool
  default     = false
}

variable "ipv6_ipam_pool_id" {
  description = "IPv6 IPAM pool ID to allocate the VPC IPv6 CIDR from."
  type        = string
  default     = null
}

variable "ipv6_netmask_length" {
  description = "Netmask length for IPv6 IPAM allocation."
  type        = number
  default     = null
}

variable "subnets" {
  description = "Advanced subnet definitions keyed by logical name. If empty, azs/private_subnets/public_subnets/database_subnets are used."
  type = map(object({
    cidr_block                      = string
    tier                            = string
    availability_zone_suffix        = optional(string, "a")
    map_public_ip_on_launch         = optional(bool, false)
    public_route                    = optional(bool, false)
    nat_route                       = optional(bool, false)
    assign_ipv6_address_on_creation = optional(bool, false)
    ipv6_subnet_index               = optional(number)
    ipv6_cidr_block                 = optional(string)
  }))
  default = {}
}

variable "azs" {
  description = "Availability zones used to generate subnet keys when using list-style subnet inputs."
  type        = list(string)
  default     = []
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks, one per AZ."
  type        = list(string)
  default     = []
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks, one per AZ."
  type        = list(string)
  default     = []
}

variable "database_subnets" {
  description = "Database subnet CIDR blocks, one per AZ."
  type        = list(string)
  default     = []
}

variable "intra_subnets" {
  description = "Intra subnet CIDR blocks, one per AZ."
  type        = list(string)
  default     = []
}

variable "enable_internet_gateway" {
  description = "Whether to create an internet gateway for public-route subnets."
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Create NAT gateways for private subnet egress. In production prefer one NAT gateway per AZ."
  type        = bool
  default     = false
}

variable "external_nat_ip_ids" {
  description = "Map of public subnet key to existing EIP allocation ID for NAT gateways."
  type        = map(string)
  default     = {}
}

variable "enable_vpn_gateway" {
  description = "Create and attach a virtual private gateway."
  type        = bool
  default     = false
}

variable "amazon_side_asn" {
  description = "Amazon side ASN for the virtual private gateway."
  type        = number
  default     = 64512
}

variable "propagate_private_route_tables_vgw" {
  description = "Enable VPN gateway route propagation on private route tables."
  type        = bool
  default     = true
}

variable "enable_direct_connect_gateway" {
  description = "Create a Direct Connect Gateway and associate it with this VPC VPN Gateway or a supplied associated gateway ID."
  type        = bool
  default     = false
}

variable "direct_connect_gateway_asn" {
  description = "Amazon side ASN for the Direct Connect Gateway."
  type        = number
  default     = 64513
}

variable "direct_connect_allowed_prefixes" {
  description = "Allowed prefixes advertised through the Direct Connect Gateway association."
  type        = list(string)
  default     = []
}

variable "direct_connect_associated_gateway_id" {
  description = "Existing VGW or TGW ID to associate with the Direct Connect Gateway. If null, the module-created VPN Gateway is used."
  type        = string
  default     = null
}

variable "single_nat_gateway" {
  description = "Create only one NAT gateway and route all NAT-enabled subnets through it. Lower cost, lower resilience."
  type        = bool
  default     = false
}

variable "enable_dhcp_options" {
  description = "Create and associate a DHCP options set."
  type        = bool
  default     = false
}

variable "dhcp_options_domain_name" {
  description = "DHCP options domain name."
  type        = string
  default     = null
}

variable "dhcp_options_domain_name_servers" {
  description = "DHCP options domain name servers."
  type        = list(string)
  default     = ["AmazonProvidedDNS"]
}

variable "dhcp_options_ntp_servers" {
  description = "DHCP options NTP servers."
  type        = list(string)
  default     = []
}

variable "manage_default_security_group" {
  description = "Manage the VPC default security group with no ingress or egress rules."
  type        = bool
  default     = false
}

variable "manage_default_network_acl" {
  description = "Manage the VPC default network ACL and detach subnets from it."
  type        = bool
  default     = false
}

variable "manage_default_route_table" {
  description = "Manage the VPC default route table with no explicit routes."
  type        = bool
  default     = false
}

variable "enable_vpc_endpoints" {
  description = "Create VPC endpoints. Disable only for emulators that do not implement CreateVpcEndpoint."
  type        = bool
  default     = true
}

variable "endpoint_services" {
  description = "Interface endpoint service names keyed by logical name."
  type        = map(string)
  default = {
    kms            = "kms"
    secretsmanager = "secretsmanager"
    logs           = "logs"
    ecr_api        = "ecr.api"
    ecr_dkr        = "ecr.dkr"
    sts            = "sts"
  }
}

variable "gateway_endpoint_subnet_keys" {
  description = "Subnet keys whose route tables should be attached to the S3 gateway endpoint."
  type        = list(string)
  default     = ["private-a", "database-a"]
}

variable "interface_endpoint_subnet_keys" {
  description = "Subnet keys where interface endpoints should be placed."
  type        = list(string)
  default     = ["private-a"]
}

variable "enable_vpc_flow_logs" {
  description = "Create VPC flow logs. Disable only for emulators that do not implement CreateFlowLogs."
  type        = bool
  default     = true
}

variable "create_database_subnet_group" {
  description = "Create an RDS DB subnet group from database subnets."
  type        = bool
  default     = false
}

variable "create_elasticache_subnet_group" {
  description = "Create an ElastiCache subnet group from database subnets."
  type        = bool
  default     = false
}

variable "create_redshift_subnet_group" {
  description = "Create a Redshift subnet group from database subnets."
  type        = bool
  default     = false
}

variable "customer_gateways" {
  description = "Customer gateways keyed by logical name."
  type = map(object({
    bgp_asn    = number
    ip_address = string
    type       = optional(string, "ipsec.1")
    tags       = optional(map(string), {})
  }))
  default = {}
}

variable "vpn_connections" {
  description = "Site-to-site VPN connections keyed by logical name."
  type = map(object({
    customer_gateway_key  = string
    transit_gateway_id    = optional(string)
    type                  = optional(string, "ipsec.1")
    static_routes_only    = optional(bool, false)
    static_routes         = optional(list(string), [])
    tunnel1_inside_cidr   = optional(string)
    tunnel2_inside_cidr   = optional(string)
    tunnel1_preshared_key = optional(string)
    tunnel2_preshared_key = optional(string)
    tags                  = optional(map(string), {})
  }))
  default = {}
}

variable "enable_transit_gateway_attachment" {
  description = "Attach this VPC to an existing Transit Gateway."
  type        = bool
  default     = false
}

variable "transit_gateway_id" {
  description = "Existing Transit Gateway ID."
  type        = string
  default     = null
}

variable "transit_gateway_attachment_subnet_keys" {
  description = "Subnet keys used for the Transit Gateway attachment."
  type        = list(string)
  default     = []
}

variable "transit_gateway_routes" {
  description = "Routes to the Transit Gateway keyed by logical name."
  type = map(object({
    destination_cidr_block = string
    route_table_keys       = list(string)
  }))
  default = {}
}

variable "transit_gateway_dns_support" {
  description = "DNS support for the Transit Gateway VPC attachment."
  type        = string
  default     = "enable"
}

variable "transit_gateway_ipv6_support" {
  description = "IPv6 support for the Transit Gateway VPC attachment."
  type        = string
  default     = "disable"
}

variable "transit_gateway_appliance_mode_support" {
  description = "Appliance mode support for the Transit Gateway VPC attachment."
  type        = string
  default     = "disable"
}

variable "transit_gateway_default_route_table_association" {
  description = "Associate attachment with the default Transit Gateway route table."
  type        = bool
  default     = true
}

variable "transit_gateway_default_route_table_propagation" {
  description = "Propagate attachment to the default Transit Gateway route table."
  type        = bool
  default     = true
}

variable "vpc_peerings" {
  description = "VPC peering requests keyed by logical name. Add route_table_keys and destination_cidr_blocks to route this VPC toward the peer."
  type = map(object({
    peer_vpc_id                               = string
    peer_owner_id                             = optional(string)
    peer_region                               = optional(string)
    auto_accept                               = optional(bool, false)
    manage_connection_options                 = optional(bool, true)
    requester_allow_remote_vpc_dns_resolution = optional(bool, true)
    accepter_allow_remote_vpc_dns_resolution  = optional(bool, true)
    route_table_keys                          = optional(list(string), [])
    destination_cidr_blocks                   = optional(list(string), [])
    tags                                      = optional(map(string), {})
  }))
  default = {}
}

variable "vpc_peering_accepters" {
  description = "Existing VPC peering requests to accept from this VPC/account side."
  type = map(object({
    vpc_peering_connection_id                = string
    auto_accept                              = optional(bool, true)
    manage_connection_options                = optional(bool, true)
    accepter_allow_remote_vpc_dns_resolution = optional(bool, true)
    tags                                     = optional(map(string), {})
  }))
  default = {}
}

variable "network_acls" {
  description = "Custom network ACLs keyed by logical name."
  type = map(object({
    subnet_tier = string
    ingress = optional(list(object({
      rule_number = number
      rule_action = string
      protocol    = string
      cidr_block  = string
      from_port   = optional(number)
      to_port     = optional(number)
    })), [])
    egress = optional(list(object({
      rule_number = number
      rule_action = string
      protocol    = string
      cidr_block  = string
      from_port   = optional(number)
      to_port     = optional(number)
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "flow_log_retention_days" {
  description = "CloudWatch Logs retention for VPC flow logs."
  type        = number
  default     = 365
}
