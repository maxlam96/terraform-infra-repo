output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Private EKS API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Cluster security group ID."
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Managed node security group ID."
  value       = module.eks.node_security_group_id
}

output "kms_key_arn" {
  description = "KMS key ARN used for Kubernetes secrets encryption."
  value       = module.eks.kms_key_arn
}

output "node_group_names" {
  description = "Managed node group names."
  value       = module.eks.node_group_names
}
