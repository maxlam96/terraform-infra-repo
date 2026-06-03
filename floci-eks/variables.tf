variable "aws_region" {
  description = "AWS-compatible region."
  type        = string
  default     = "us-east-1"
}

variable "floci_endpoint" {
  description = "Remote Floci AWS-compatible endpoint used for plan-time provider configuration."
  type        = string
  default     = "http://192.168.251.1:4566"
}

variable "environment" {
  description = "Environment tag and policy context."
  type        = string
  default     = "staging"
}

variable "project" {
  description = "Project name used in names and tags."
  type        = string
  default     = "floci-eks-lab"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "platform"
}

variable "tags" {
  description = "Additional tags merged into supported resources."
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID for EKS."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version."
  type        = string
  default     = "1.30"
}

variable "cluster_log_retention_days" {
  description = "CloudWatch retention for EKS control plane logs."
  type        = number
  default     = 90
}

variable "autoscaling_mode" {
  description = "Autoscaling integration mode for EKS worker capacity."
  type        = string
  default     = "cluster-autoscaler"

  validation {
    condition     = contains(["cluster-autoscaler", "karpenter", "both"], var.autoscaling_mode)
    error_message = "autoscaling_mode must be cluster-autoscaler, karpenter, or both."
  }
}

variable "create_node_ingress_security_group_rules" {
  description = "Create EKS node ingress security group rules."
  type        = bool
  default     = true
}

variable "create_node_egress_security_group_rule" {
  description = "Create EKS node egress security group rule."
  type        = bool
  default     = true
}

variable "create_managed_node_groups" {
  description = "Create AWS managed EKS node groups."
  type        = bool
  default     = true
}

variable "create_self_managed_node_groups" {
  description = "Create self-managed EKS node groups with EC2 Launch Templates and Auto Scaling Groups."
  type        = bool
  default     = false
}

variable "create_floci_node_group_placeholders" {
  description = "Create Terraform-only node group placeholders when Floci does not support EC2 launch templates or EKS node group APIs."
  type        = bool
  default     = false
}

variable "self_managed_node_ami_id" {
  description = "AMI ID used by self-managed node groups."
  type        = string
  default     = "ami-0abcdef1234567890"
}

variable "create_cluster_addons" {
  description = "Create EKS managed addons."
  type        = bool
  default     = true
}

variable "node_groups" {
  description = "Managed node groups."
  type = map(object({
    ami_type        = optional(string, "AL2_x86_64")
    capacity_type   = optional(string, "ON_DEMAND")
    desired_size    = number
    disk_size       = optional(number, 50)
    instance_types  = list(string)
    labels          = optional(map(string), {})
    max_size        = number
    max_unavailable = optional(number, 1)
    min_size        = number
    tags            = optional(map(string), {})
  }))
}

variable "cluster_addons" {
  description = "EKS managed addons."
  type = map(object({
    addon_version = optional(string)
    tags          = optional(map(string), {})
  }))
  default = {
    coredns      = {}
    "kube-proxy" = {}
    "vpc-cni"    = {}
  }
}
