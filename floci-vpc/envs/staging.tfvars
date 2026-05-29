aws_region  = "ap-southeast-1"
environment = "staging"
project     = "floci-vpc-lab"

vpc_cidr            = "10.40.0.0/16"
public_subnet_cidr  = "10.40.1.0/24"
private_subnet_cidr = "10.40.2.0/24"
db_subnet_cidr      = "10.40.3.0/24"

enable_vpc_endpoints = false
enable_vpc_flow_logs = false
