aws_region  = "us-east-1"
environment = "staging"
project     = "floci-vpc-lab"
# owner       = "platform"

name = "floci-vpc-lab-staging"
cidr = "10.40.0.0/16"

azs              = ["us-east-1"]
public_subnets   = ["10.40.1.0/24"]
private_subnets  = ["10.40.2.0/24"]
database_subnets = ["10.40.3.0/24"]

enable_nat_gateway   = false
enable_vpc_endpoints = false
enable_vpc_flow_logs = false
