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
autoscaling_mode           = "both"

node_groups = {
  web = {
    capacity_type   = "ON_DEMAND"
    desired_size    = 3
    disk_size       = 100
    instance_types  = ["m6i.large"]
    max_size        = 9
    max_unavailable = 1
    min_size        = 3
    labels = {
      workload = "web"
    }
    tags = {
      WorkloadTier = "web"
    }
  }
  backend = {
    capacity_type   = "ON_DEMAND"
    desired_size    = 3
    disk_size       = 100
    instance_types  = ["m6i.large"]
    max_size        = 12
    max_unavailable = 1
    min_size        = 3
    labels = {
      workload = "backend"
    }
    tags = {
      WorkloadTier = "backend"
    }
  }
  worker = {
    capacity_type   = "ON_DEMAND"
    desired_size    = 3
    disk_size       = 100
    instance_types  = ["m6i.large"]
    max_size        = 15
    max_unavailable = 1
    min_size        = 3
    labels = {
      workload = "worker"
    }
    tags = {
      WorkloadTier = "worker"
    }
  }
}
