# VPC Module

Reusable AWS-compatible VPC module for Floci labs and real AWS-style Terraform projects.

## Example

```hcl
module "vpc" {
  source = "../modules/vpc"

  aws_region  = "ap-southeast-1"
  environment = "staging"
  project     = "payments-api"
  owner       = "platform"

  name = "payments-api-staging"
  cidr = "10.40.0.0/16"

  azs              = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  public_subnets   = ["10.40.1.0/24", "10.40.2.0/24", "10.40.3.0/24"]
  private_subnets  = ["10.40.11.0/24", "10.40.12.0/24", "10.40.13.0/24"]
  database_subnets = ["10.40.21.0/24", "10.40.22.0/24", "10.40.23.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false
  enable_vpn_gateway = true
  enable_direct_connect_gateway = true
  direct_connect_gateway_asn = 64513
  direct_connect_allowed_prefixes = ["192.168.10.0/24"]
  enable_dhcp_options = true

  customer_gateways = {
    branch = {
      bgp_asn    = 65010
      ip_address = "203.0.113.10"
    }
  }

  vpn_connections = {
    branch-backup = {
      customer_gateway_key = "branch"
      static_routes_only   = false
      tunnel1_inside_cidr  = "169.254.21.0/30"
      tunnel2_inside_cidr  = "169.254.22.0/30"
    }
  }

  vpc_peerings = {
    shared-services = {
      peer_vpc_id             = "vpc-0123456789abcdef0"
      auto_accept             = true
      route_table_keys        = ["private-a", "private-b", "private-c"]
      destination_cidr_blocks = ["10.60.0.0/16"]
    }
  }

  manage_default_security_group = true
  manage_default_network_acl    = true
  manage_default_route_table    = true

  create_database_subnet_group    = true
  create_elasticache_subnet_group = true
  create_redshift_subnet_group    = true

  # Keep these true in real AWS. Disable only when the emulator lacks the APIs.
  enable_vpc_endpoints = true
  enable_vpc_flow_logs = true
}
```

## Notes

- `azs`, `private_subnets`, `public_subnets`, and `database_subnets` follow the same style as `terraform-aws-modules/vpc/aws`.
- `subnets` is still available for advanced custom topologies; if it is set, it overrides the list-style subnet inputs.
- `public_route = true` adds a `0.0.0.0/0` route through the module internet gateway.
- `nat_route = true` adds a `0.0.0.0/0` route through a NAT gateway for that subnet.
- `enable_nat_gateway = true` creates NAT gateways in public subnets. Use `single_nat_gateway = false` for one NAT per AZ in production.
- VPC endpoints and flow logs are enabled by default for production-style hardening.
- For Floci staging, set `enable_vpc_endpoints = false` and `enable_vpc_flow_logs = false` if those APIs are unsupported.

## Production Guardrails

When `environment = "production"`, the module fails plan/apply unless these controls are enabled:

- At least 3 availability zones
- At least 3 public, 3 private, and 3 database subnets
- NAT gateway enabled
- `single_nat_gateway = false`
- At least 3 NAT-routed subnets
- VPC endpoints enabled
- VPC flow logs enabled
- Default security group managed and restricted
- Default network ACL managed

## Production Multi-AZ Pattern

Use at least three AZs for banking or finance-style production workloads:

```hcl
name = "payments-production"
cidr = "10.50.0.0/16"

azs              = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
public_subnets   = ["10.50.1.0/24", "10.50.2.0/24", "10.50.3.0/24"]
private_subnets  = ["10.50.11.0/24", "10.50.12.0/24", "10.50.13.0/24"]
database_subnets = ["10.50.21.0/24", "10.50.22.0/24", "10.50.23.0/24"]
```

## Production Options Covered

- Multi-AZ public/private/database subnets
- NAT gateway per AZ
- Virtual private gateway and private route table propagation
- DHCP options set
- VPC endpoints for S3, KMS, Secrets Manager, CloudWatch Logs, ECR, and STS
- VPC flow logs encrypted with KMS
- Restricted default security group
- Managed default network ACL and default route table
- RDS DB subnet group
- ElastiCache subnet group
- Redshift subnet group
- IPv6 and IPAM inputs
- External/reused NAT EIP allocation IDs
- Customer gateways and site-to-site VPN connections
- Direct Connect Gateway association for primary hybrid connectivity
- Transit Gateway VPC attachment and routes
- VPC peering requests, accepters, DNS options, and route table entries
- Custom network ACLs and subnet associations
- Intra subnets for internal-only workloads

## Hybrid Connectivity Pattern

For banking or branch connectivity, use this routing intent:

- Direct Connect is the primary private path.
- IPSec Site-to-Site VPN is the backup path.
- BGP is enabled by setting `static_routes_only = false` on `vpn_connections`.
- Path preference is normally controlled by the on-premises router through BGP local preference or AS path prepending.
- In Floci labs, keep `enable_direct_connect_gateway = false` if the emulator does not support Direct Connect APIs.
