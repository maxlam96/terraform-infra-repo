output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Private EKS API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "Cluster security group ID."
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Managed node security group ID."
  value       = aws_security_group.nodes.id
}

output "cluster_role_arn" {
  description = "Cluster IAM role ARN."
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "Node IAM role ARN."
  value       = aws_iam_role.node.arn
}

output "kms_key_arn" {
  description = "KMS key ARN used for Kubernetes secrets encryption."
  value       = aws_kms_key.cluster.arn
}

output "node_group_names" {
  description = "Managed node group names."
  value       = { for key, group in aws_eks_node_group.managed : key => group.node_group_name }
}
