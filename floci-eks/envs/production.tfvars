aws_region  = "ap-southeast-1"
environment = "production"
project     = "floci-eks-lab"
owner       = "platform"

cluster_name = "floci-eks-lab-production"

vpc_id = "vpc-replace-with-production-vpc"
private_subnet_ids = [
  "subnet-replace-private-a",
  "subnet-replace-private-b",
  "subnet-replace-private-c",
]

kubernetes_version         = "1.30"
cluster_log_retention_days = 365

node_groups = {
  system = {
    desired_size   = 3
    instance_types = ["m6i.large"]
    max_size       = 6
    min_size       = 3
    labels = {
      workload = "system"
    }
    tags = {
      WorkloadTier = "system"
    }
  }
  app = {
    capacity_type   = "ON_DEMAND"
    desired_size    = 3
    disk_size       = 100
    instance_types  = ["m6i.large"]
    max_size        = 9
    max_unavailable = 1
    min_size        = 3
    labels = {
      workload = "app"
    }
    tags = {
      WorkloadTier = "application"
    }
  }
}
