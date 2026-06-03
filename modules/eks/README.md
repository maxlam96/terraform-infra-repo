# EKS Module

Reusable EKS module for regulated AWS workloads.

## Security Defaults

- Private-only Kubernetes API endpoint.
- Kubernetes secrets encrypted with a dedicated KMS key.
- Full control plane logs enabled: `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`.
- Managed node groups run in private subnets.
- SSH remote access is not configured on node groups.
- Node groups must run at least two desired nodes.
- Workload capacity is split into `web`, `backend`, and `worker` managed node groups by default.
- Cluster Autoscaler tags are enabled when `autoscaling_mode = "cluster-autoscaler"` or `"both"`.
- Karpenter discovery tags, controller IAM policy, interruption SQS queue, and EventBridge interruption rules are created when `autoscaling_mode = "karpenter"` or `"both"`.
- IAM roles use AWS managed EKS policies without administrator attachments.

## Example

```hcl
module "eks" {
  source = "../modules/eks"

  cluster_name = "payments-production"
  environment  = "production"
  owner        = "platform"
  project      = "payments"

  vpc_id = "vpc-1234567890abcdef0"
	  private_subnet_ids = [
	    "subnet-private-a",
	    "subnet-private-b",
	    "subnet-private-c",
	  ]

	  autoscaling_mode = "both"

	  node_groups = {
	    web = {
	      desired_size   = 3
	      instance_types = ["m6i.large"]
	      max_size       = 9
	      min_size       = 3
	    }
	    backend = {
	      desired_size   = 3
	      instance_types = ["m6i.large"]
	      max_size       = 12
	      min_size       = 3
	    }
	    worker = {
	      desired_size   = 3
	      instance_types = ["m6i.large"]
	      max_size       = 15
	      min_size       = 3
	    }
	  }
	}
	```

## Floci Note

Floci can be used to validate and apply the EKS control plane, IAM, KMS,
CloudWatch, security groups, and Karpenter support resources in this lab. Some
emulated APIs still differ from AWS, so `floci-eks/envs/staging.tfvars` disables
managed node groups, managed addons, cluster logging/access/encryption config,
and node ingress security group rules. Keep those flags enabled for real AWS
environments.
