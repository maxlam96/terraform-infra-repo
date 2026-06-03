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

output "autoscaling_mode" {
  description = "Autoscaling integration mode used by the module."
  value       = module.eks.autoscaling_mode
}

output "karpenter_controller_policy_arn" {
  description = "IAM policy ARN for the Karpenter controller when Karpenter is enabled."
  value       = module.eks.karpenter_controller_policy_arn
}

output "karpenter_interruption_queue_url" {
  description = "SQS queue URL for Karpenter interruption handling when Karpenter is enabled."
  value       = module.eks.karpenter_interruption_queue_url
}
