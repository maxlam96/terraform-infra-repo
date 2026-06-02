aws_region  = "us-east-1"
environment = "staging"
project     = "floci-eks-lab"
owner       = "platform"

cluster_name = "floci-eks-lab-staging"

# Floci does not emulate the EKS control plane; these IDs are plan-time lab inputs.
vpc_id = "vpc-599a9b14"
private_subnet_ids = [
  "subnet-e59f9890",
  "subnet-floci-private-b",
]

kubernetes_version         = "1.30"
cluster_log_retention_days = 365

node_groups = {
  system = {
    desired_size   = 2
    instance_types = ["t3.large"]
    max_size       = 4
    min_size       = 2
    labels = {
      workload = "system"
    }
    tags = {
      WorkloadTier = "system"
    }
  }
}
