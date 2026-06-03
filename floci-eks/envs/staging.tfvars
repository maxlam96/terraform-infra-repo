aws_region  = "us-east-1"
environment = "staging"
project     = "floci-eks-lab"
owner       = "platform"

cluster_name = "floci-eks-lab-staging"

# Use the VPC created by the floci-vpc staging pipeline.
vpc_id = "vpc-5d4764bd"
private_subnet_ids = [
  "subnet-35c469d1",
  "subnet-ae1fbf67",
]

kubernetes_version         = "1.30"
cluster_log_retention_days = 365
autoscaling_mode           = "both"

node_groups = {
  web = {
    desired_size   = 2
    instance_types = ["t3.large"]
    max_size       = 6
    min_size       = 2
    labels = {
      workload = "web"
    }
    tags = {
      WorkloadTier = "web"
    }
  }
  backend = {
    desired_size   = 2
    instance_types = ["t3.large"]
    max_size       = 8
    min_size       = 2
    labels = {
      workload = "backend"
    }
    tags = {
      WorkloadTier = "backend"
    }
  }
  worker = {
    desired_size   = 2
    instance_types = ["t3.large"]
    max_size       = 10
    min_size       = 2
    labels = {
      workload = "worker"
    }
    tags = {
      WorkloadTier = "worker"
    }
  }
}
