# EKS Module

Reusable EKS module for regulated AWS workloads.

## Security Defaults

- Private-only Kubernetes API endpoint.
- Kubernetes secrets encrypted with a dedicated KMS key.
- Full control plane logs enabled: `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`.
- Managed node groups run in private subnets.
- SSH remote access is not configured on node groups.
- Node groups must run at least two desired nodes.
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

  node_groups = {
    system = {
      desired_size   = 3
      instance_types = ["m6i.large"]
      max_size       = 6
      min_size       = 3
    }
  }
}
```

## Floci Note

Floci is useful for CI plan and OPA validation here, but it currently does not emulate the EKS control plane APIs. Keep Jenkins `RUN_APPLY=false` for `TF_DIR=floci-eks` unless you are targeting real AWS with a separate provider configuration.
