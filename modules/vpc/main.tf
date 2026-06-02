locals {
  name_prefix = var.name != null ? var.name : "${var.project}-${var.environment}"

  vpc_cidr = var.cidr != null ? var.cidr : var.vpc_cidr

  az_suffixes = [
    for az in var.azs :
    replace(az, var.aws_region, "")
  ]

  list_style_subnets = merge(
    {
      for idx, cidr_block in var.public_subnets :
      "public-${local.az_suffixes[idx]}" => {
        cidr_block                      = cidr_block
        tier                            = "public"
        availability_zone_suffix        = local.az_suffixes[idx]
        map_public_ip_on_launch         = false
        public_route                    = true
        nat_route                       = false
        assign_ipv6_address_on_creation = false
        ipv6_subnet_index               = var.enable_ipv6 ? idx : null
        ipv6_cidr_block                 = null
      }
    },
    {
      for idx, cidr_block in var.private_subnets :
      "private-${local.az_suffixes[idx]}" => {
        cidr_block                      = cidr_block
        tier                            = "private"
        availability_zone_suffix        = local.az_suffixes[idx]
        map_public_ip_on_launch         = false
        public_route                    = false
        nat_route                       = var.enable_nat_gateway
        assign_ipv6_address_on_creation = false
        ipv6_subnet_index               = var.enable_ipv6 ? idx + length(var.public_subnets) : null
        ipv6_cidr_block                 = null
      }
    },
    {
      for idx, cidr_block in var.database_subnets :
      "database-${local.az_suffixes[idx]}" => {
        cidr_block                      = cidr_block
        tier                            = "database"
        availability_zone_suffix        = local.az_suffixes[idx]
        map_public_ip_on_launch         = false
        public_route                    = false
        nat_route                       = false
        assign_ipv6_address_on_creation = false
        ipv6_subnet_index               = var.enable_ipv6 ? idx + length(var.public_subnets) + length(var.private_subnets) : null
        ipv6_cidr_block                 = null
      }
    },
    {
      for idx, cidr_block in var.intra_subnets :
      "intra-${local.az_suffixes[idx]}" => {
        cidr_block                      = cidr_block
        tier                            = "intra"
        availability_zone_suffix        = local.az_suffixes[idx]
        map_public_ip_on_launch         = false
        public_route                    = false
        nat_route                       = false
        assign_ipv6_address_on_creation = false
        ipv6_subnet_index               = var.enable_ipv6 ? idx + length(var.public_subnets) + length(var.private_subnets) + length(var.database_subnets) : null
        ipv6_cidr_block                 = null
      }
    }
  )

  effective_subnets = length(var.subnets) > 0 ? var.subnets : local.list_style_subnets

  common_tags = merge(
    {
      Environment = var.environment
      Owner       = var.owner
      Project     = var.project
      ManagedBy   = "terraform"
    },
    var.tags
  )

  endpoint_services = var.endpoint_services

  public_subnet_keys = sort([
    for key, subnet in local.effective_subnets :
    key
    if subnet.public_route
  ])

  production_mode = lower(var.environment) == "production"

  availability_zone_suffixes = distinct([
    for subnet in local.effective_subnets :
    subnet.availability_zone_suffix
  ])

  subnet_tiers = {
    for tier in distinct([for subnet in local.effective_subnets : subnet.tier]) :
    tier => [
      for key, subnet in local.effective_subnets :
      key
      if subnet.tier == tier
    ]
  }

  nat_route_subnet_keys = [
    for key, subnet in local.effective_subnets :
    key
    if subnet.nat_route
  ]

  nat_gateway_subnet_keys = var.enable_nat_gateway ? (
    var.single_nat_gateway ? slice(local.public_subnet_keys, 0, min(1, length(local.public_subnet_keys))) : local.public_subnet_keys
  ) : []

  nat_gateway_subnet_key_by_az = {
    for key in local.nat_gateway_subnet_keys :
    local.effective_subnets[key].availability_zone_suffix => key
  }

  nat_gateway_key_by_subnet_key = {
    for key, subnet in local.effective_subnets :
    key => (
      var.single_nat_gateway ?
      local.nat_gateway_subnet_keys[0] :
      lookup(local.nat_gateway_subnet_key_by_az, subnet.availability_zone_suffix, local.nat_gateway_subnet_keys[0])
    )
    if var.enable_nat_gateway && subnet.nat_route && length(local.nat_gateway_subnet_keys) > 0
  }

  gateway_endpoint_route_table_ids = [
    for subnet_key in var.gateway_endpoint_subnet_keys :
    aws_route_table.this[subnet_key].id
    if contains(keys(aws_route_table.this), subnet_key)
  ]

  interface_endpoint_subnet_ids = [
    for subnet_key in var.interface_endpoint_subnet_keys :
    aws_subnet.this[subnet_key].id
    if contains(keys(aws_subnet.this), subnet_key)
  ]

  private_route_table_ids = [
    for key in lookup(local.subnet_tiers, "private", []) :
    aws_route_table.this[key].id
  ]

  private_route_table_ids_by_key = {
    for key in lookup(local.subnet_tiers, "private", []) :
    key => aws_route_table.this[key].id
  }

  database_subnet_ids = [
    for key in lookup(local.subnet_tiers, "database", []) :
    aws_subnet.this[key].id
  ]

  tgw_attachment_subnet_ids = [
    for key in var.transit_gateway_attachment_subnet_keys :
    aws_subnet.this[key].id
    if contains(keys(aws_subnet.this), key)
  ]

  tgw_routes = length(var.transit_gateway_routes) > 0 ? merge([
    for route_key, route in var.transit_gateway_routes : {
      for route_table_key in route.route_table_keys :
      "${route_key}-${route_table_key}" => {
        destination_cidr_block = route.destination_cidr_block
        route_table_key        = route_table_key
      }
    }
  ]...) : {}

  vpc_peering_route_pairs = flatten([
    for peering_key, peering in var.vpc_peerings : [
      for pair in setproduct(peering.route_table_keys, peering.destination_cidr_blocks) :
      {
        route_key              = "${peering_key}-${pair[0]}-${replace(pair[1], "/", "_")}"
        peering_key            = peering_key
        route_table_key        = pair[0]
        destination_cidr_block = pair[1]
      }
    ]
  ])

  vpc_peering_routes = {
    for route in local.vpc_peering_route_pairs :
    route.route_key => route
  }

  network_acl_subnet_associations = length(var.network_acls) > 0 ? merge([
    for acl_key, acl in var.network_acls : {
      for subnet_key, subnet in local.effective_subnets :
      "${acl_key}-${subnet_key}" => {
        acl_key    = acl_key
        subnet_key = subnet_key
      }
      if subnet.tier == acl.subnet_tier
    }
  ]...) : {}

  customer_gateway_static_routes = length(var.vpn_connections) > 0 ? merge([
    for vpn_key, vpn in var.vpn_connections : {
      for idx, route in vpn.static_routes :
      "${vpn_key}-${idx}" => {
        vpn_key                = vpn_key
        destination_cidr_block = route
      }
    }
  ]...) : {}
}

resource "terraform_data" "guardrails" {
  input = {
    environment = var.environment
    project     = var.project
  }

  lifecycle {
    precondition {
      condition     = !local.production_mode || length(local.availability_zone_suffixes) >= 3
      error_message = "Production VPCs must span at least three availability zones."
    }

    precondition {
      condition     = !local.production_mode || length(lookup(local.subnet_tiers, "public", [])) >= 3
      error_message = "Production VPCs must define at least three public subnets."
    }

    precondition {
      condition     = !local.production_mode || length(lookup(local.subnet_tiers, "private", [])) >= 3
      error_message = "Production VPCs must define at least three private subnets."
    }

    precondition {
      condition     = !local.production_mode || length(lookup(local.subnet_tiers, "database", [])) >= 3
      error_message = "Production VPCs must define at least three database subnets."
    }

    precondition {
      condition     = !local.production_mode || var.enable_nat_gateway
      error_message = "Production VPCs must enable NAT gateways for private subnet egress."
    }

    precondition {
      condition     = !local.production_mode || !var.single_nat_gateway
      error_message = "Production VPCs must not use a single NAT gateway. Use one NAT gateway per AZ."
    }

    precondition {
      condition     = !local.production_mode || length(local.nat_route_subnet_keys) >= 3
      error_message = "Production VPCs must route private subnets through NAT gateways."
    }

    precondition {
      condition     = !local.production_mode || var.enable_vpc_endpoints
      error_message = "Production VPCs must enable VPC endpoints."
    }

    precondition {
      condition     = !local.production_mode || var.enable_vpc_flow_logs
      error_message = "Production VPCs must enable VPC flow logs."
    }

    precondition {
      condition     = local.vpc_cidr != null || (var.ipv4_ipam_pool_id != null && var.ipv4_netmask_length != null)
      error_message = "Either cidr/vpc_cidr or ipv4_ipam_pool_id plus ipv4_netmask_length must be set."
    }

    precondition {
      condition     = length(var.subnets) > 0 || length(var.public_subnets) <= length(var.azs)
      error_message = "public_subnets cannot contain more CIDR blocks than azs."
    }

    precondition {
      condition     = length(var.subnets) > 0 || count([for suffix in local.az_suffixes : suffix if suffix == ""]) == 0
      error_message = "azs must contain full availability zone names like us-east-1a, not only the region name."
    }

    precondition {
      condition     = length(var.subnets) > 0 || length(var.private_subnets) <= length(var.azs)
      error_message = "private_subnets cannot contain more CIDR blocks than azs."
    }

    precondition {
      condition     = length(var.subnets) > 0 || length(var.database_subnets) <= length(var.azs)
      error_message = "database_subnets cannot contain more CIDR blocks than azs."
    }

    precondition {
      condition     = !local.production_mode || var.manage_default_security_group
      error_message = "Production VPCs must manage and restrict the default security group."
    }

    precondition {
      condition     = !local.production_mode || var.manage_default_network_acl
      error_message = "Production VPCs must manage the default network ACL."
    }

    precondition {
      condition     = !var.enable_direct_connect_gateway || var.enable_vpn_gateway || var.direct_connect_associated_gateway_id != null
      error_message = "Direct Connect Gateway requires enable_vpn_gateway=true or direct_connect_associated_gateway_id to associate with a VGW/TGW."
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block                       = local.vpc_cidr
  ipv4_ipam_pool_id                = var.ipv4_ipam_pool_id
  ipv4_netmask_length              = var.ipv4_netmask_length
  assign_generated_ipv6_cidr_block = var.enable_ipv6
  ipv6_ipam_pool_id                = var.ipv6_ipam_pool_id
  ipv6_netmask_length              = var.ipv6_netmask_length
  enable_dns_hostnames             = var.enable_dns_hostnames
  enable_dns_support               = var.enable_dns_support

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  count = var.enable_internet_gateway ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_vpn_gateway" "this" {
  count = var.enable_vpn_gateway ? 1 : 0

  vpc_id          = aws_vpc.main.id
  amazon_side_asn = var.amazon_side_asn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vgw"
  })
}

resource "aws_vpn_gateway_route_propagation" "private" {
  for_each = var.enable_vpn_gateway && var.propagate_private_route_tables_vgw ? local.private_route_table_ids_by_key : {}

  vpn_gateway_id = aws_vpn_gateway.this[0].id
  route_table_id = each.value
}

resource "aws_dx_gateway" "this" {
  count = var.enable_direct_connect_gateway ? 1 : 0

  name            = "${local.name_prefix}-dx-gateway"
  amazon_side_asn = var.direct_connect_gateway_asn
}

resource "aws_dx_gateway_association" "this" {
  count = var.enable_direct_connect_gateway ? 1 : 0

  dx_gateway_id         = aws_dx_gateway.this[0].id
  associated_gateway_id = var.direct_connect_associated_gateway_id != null ? var.direct_connect_associated_gateway_id : aws_vpn_gateway.this[0].id
  allowed_prefixes      = var.direct_connect_allowed_prefixes
}

resource "aws_vpc_dhcp_options" "this" {
  count = var.enable_dhcp_options ? 1 : 0

  domain_name          = var.dhcp_options_domain_name
  domain_name_servers  = var.dhcp_options_domain_name_servers
  ntp_servers          = var.dhcp_options_ntp_servers
  netbios_name_servers = var.dhcp_options_netbios_name_servers
  netbios_node_type    = var.dhcp_options_netbios_node_type

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-dhcp-options"
  })
}

resource "aws_vpc_dhcp_options_association" "this" {
  count = var.enable_dhcp_options ? 1 : 0

  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}

resource "aws_default_security_group" "this" {
  count = var.manage_default_security_group ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-default-sg-restricted"
  })
}

resource "aws_default_network_acl" "this" {
  count = var.manage_default_network_acl ? 1 : 0

  default_network_acl_id = aws_vpc.main.default_network_acl_id
  subnet_ids             = []

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-default-nacl-restricted"
  })
}

resource "aws_default_route_table" "this" {
  count = var.manage_default_route_table ? 1 : 0

  default_route_table_id = aws_vpc.main.default_route_table_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-default-rt-restricted"
  })
}

resource "aws_subnet" "this" {
  for_each = local.effective_subnets

  vpc_id                          = aws_vpc.main.id
  cidr_block                      = each.value.cidr_block
  availability_zone               = "${var.aws_region}${each.value.availability_zone_suffix}"
  map_public_ip_on_launch         = each.value.map_public_ip_on_launch
  assign_ipv6_address_on_creation = each.value.assign_ipv6_address_on_creation
  ipv6_cidr_block                 = var.enable_ipv6 && each.value.ipv6_subnet_index != null ? cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, each.value.ipv6_subnet_index) : each.value.ipv6_cidr_block

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}"
    Tier = each.value.tier
  })
}

resource "aws_route_table" "this" {
  for_each = local.effective_subnets

  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = each.value.public_route && var.enable_internet_gateway ? [1] : []

    content {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.main[0].id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-rt"
  })
}

resource "aws_route_table_association" "this" {
  for_each = local.effective_subnets

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.key].id
}

resource "aws_eip" "nat" {
  for_each = toset([
    for key in local.nat_gateway_subnet_keys :
    key
    if !contains(keys(var.external_nat_ip_ids), key)
  ])

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-nat-eip"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_gateway_subnet_keys)

  allocation_id = contains(keys(var.external_nat_ip_ids), each.key) ? var.external_nat_ip_ids[each.key] : aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.this[each.key].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route" "nat" {
  for_each = local.nat_gateway_key_by_subnet_key

  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.value].id
}

resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_vpc_endpoints ? 1 : 0

  name        = "${local.name_prefix}-vpc-endpoints"
  description = "Allow HTTPS from VPC CIDR to interface VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    description = "HTTPS response traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-endpoints-sg"
  })
}

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_vpc_endpoints && length(local.gateway_endpoint_route_table_ids) > 0 ? 1 : 0

  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.gateway_endpoint_route_table_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = var.enable_vpc_endpoints ? local.endpoint_services : {}

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = false
  subnet_ids          = local.interface_endpoint_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${replace(each.value, ".", "-")}-endpoint"
  })
}

resource "aws_customer_gateway" "this" {
  for_each = var.customer_gateways

  bgp_asn    = each.value.bgp_asn
  ip_address = each.value.ip_address
  type       = each.value.type

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-cgw"
  }, each.value.tags)
}

resource "aws_vpn_connection" "this" {
  for_each = var.vpn_connections

  customer_gateway_id = aws_customer_gateway.this[each.value.customer_gateway_key].id
  vpn_gateway_id      = var.enable_vpn_gateway ? aws_vpn_gateway.this[0].id : null
  transit_gateway_id  = each.value.transit_gateway_id
  type                = each.value.type
  static_routes_only  = each.value.static_routes_only

  tunnel1_inside_cidr   = each.value.tunnel1_inside_cidr
  tunnel2_inside_cidr   = each.value.tunnel2_inside_cidr
  tunnel1_preshared_key = each.value.tunnel1_preshared_key
  tunnel2_preshared_key = each.value.tunnel2_preshared_key

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-vpn"
  }, each.value.tags)
}

resource "aws_vpn_connection_route" "this" {
  for_each = local.customer_gateway_static_routes

  vpn_connection_id      = aws_vpn_connection.this[each.value.vpn_key].id
  destination_cidr_block = each.value.destination_cidr_block
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count = var.enable_transit_gateway_attachment ? 1 : 0

  subnet_ids         = local.tgw_attachment_subnet_ids
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.main.id

  dns_support                                     = var.transit_gateway_dns_support
  ipv6_support                                    = var.transit_gateway_ipv6_support
  appliance_mode_support                          = var.transit_gateway_appliance_mode_support
  transit_gateway_default_route_table_association = var.transit_gateway_default_route_table_association
  transit_gateway_default_route_table_propagation = var.transit_gateway_default_route_table_propagation

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tgw-attachment"
  })
}

resource "aws_route" "transit_gateway" {
  for_each = var.enable_transit_gateway_attachment ? local.tgw_routes : {}

  route_table_id         = aws_route_table.this[each.value.route_table_key].id
  destination_cidr_block = each.value.destination_cidr_block
  transit_gateway_id     = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

resource "aws_vpc_peering_connection" "this" {
  for_each = var.vpc_peerings

  vpc_id        = aws_vpc.main.id
  peer_vpc_id   = each.value.peer_vpc_id
  peer_owner_id = each.value.peer_owner_id
  peer_region   = each.value.peer_region
  auto_accept   = each.value.auto_accept

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-pcx"
  }, each.value.tags)
}

resource "aws_vpc_peering_connection_options" "this" {
  for_each = {
    for key, peering in var.vpc_peerings :
    key => peering
    if peering.auto_accept && peering.manage_connection_options
  }

  vpc_peering_connection_id = aws_vpc_peering_connection.this[each.key].id

  requester {
    allow_remote_vpc_dns_resolution = each.value.requester_allow_remote_vpc_dns_resolution
  }

  accepter {
    allow_remote_vpc_dns_resolution = each.value.accepter_allow_remote_vpc_dns_resolution
  }
}

resource "aws_vpc_peering_connection_accepter" "this" {
  for_each = var.vpc_peering_accepters

  vpc_peering_connection_id = each.value.vpc_peering_connection_id
  auto_accept               = each.value.auto_accept

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-pcx-accepter"
  }, each.value.tags)
}

resource "aws_vpc_peering_connection_options" "accepter" {
  for_each = {
    for key, accepter in var.vpc_peering_accepters :
    key => accepter
    if accepter.manage_connection_options
  }

  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.this[each.key].id

  accepter {
    allow_remote_vpc_dns_resolution = each.value.accepter_allow_remote_vpc_dns_resolution
  }
}

resource "aws_route" "vpc_peering" {
  for_each = local.vpc_peering_routes

  route_table_id            = aws_route_table.this[each.value.route_table_key].id
  destination_cidr_block    = each.value.destination_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.this[each.value.peering_key].id
}

resource "aws_network_acl" "this" {
  for_each = var.network_acls

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}-nacl"
    Tier = each.value.subnet_tier
  }, each.value.tags)
}

resource "aws_network_acl_rule" "ingress" {
  for_each = length(var.network_acls) > 0 ? merge([
    for acl_key, acl in var.network_acls : {
      for rule in acl.ingress :
      "${acl_key}-ingress-${rule.rule_number}" => merge(rule, { acl_key = acl_key })
    }
  ]...) : {}

  network_acl_id = aws_network_acl.this[each.value.acl_key].id
  egress         = false
  rule_number    = each.value.rule_number
  rule_action    = each.value.rule_action
  protocol       = each.value.protocol
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

resource "aws_network_acl_rule" "egress" {
  for_each = length(var.network_acls) > 0 ? merge([
    for acl_key, acl in var.network_acls : {
      for rule in acl.egress :
      "${acl_key}-egress-${rule.rule_number}" => merge(rule, { acl_key = acl_key })
    }
  ]...) : {}

  network_acl_id = aws_network_acl.this[each.value.acl_key].id
  egress         = true
  rule_number    = each.value.rule_number
  rule_action    = each.value.rule_action
  protocol       = each.value.protocol
  cidr_block     = each.value.cidr_block
  from_port      = each.value.from_port
  to_port        = each.value.to_port
}

resource "aws_network_acl_association" "this" {
  for_each = local.network_acl_subnet_associations

  network_acl_id = aws_network_acl.this[each.value.acl_key].id
  subnet_id      = aws_subnet.this[each.value.subnet_key].id
}

resource "aws_db_subnet_group" "database" {
  count = var.create_database_subnet_group && length(local.database_subnet_ids) > 0 ? 1 : 0

  name        = "${local.name_prefix}-database"
  description = "Database subnet group for ${local.name_prefix}"
  subnet_ids  = local.database_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-subnet-group"
  })
}

resource "aws_elasticache_subnet_group" "database" {
  count = var.create_elasticache_subnet_group && length(local.database_subnet_ids) > 0 ? 1 : 0

  name       = "${local.name_prefix}-elasticache"
  subnet_ids = local.database_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-elasticache-subnet-group"
  })
}

resource "aws_redshift_subnet_group" "database" {
  count = var.create_redshift_subnet_group && length(local.database_subnet_ids) > 0 ? 1 : 0

  name       = "${local.name_prefix}-redshift"
  subnet_ids = local.database_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redshift-subnet-group"
  })
}

resource "aws_kms_key" "logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  description             = "KMS key for ${local.name_prefix} VPC flow logs"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccountAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::000000000000:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-logs-kms"
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name              = "/aws/vpc-flow-logs/${local.name_prefix}"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = aws_kms_key.logs[0].arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-flow-logs"
  })
}

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name = "${local.name_prefix}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc-flow-logs-role"
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name = "${local.name_prefix}-vpc-flow-logs"
  role = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.vpc_flow_logs[0].arn,
          "${aws_cloudwatch_log_group.vpc_flow_logs[0].arn}:*"
        ]
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.vpc_flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-flow-log"
  })
}
