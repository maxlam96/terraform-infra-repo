variable "cluster_name" {
  description = "EKS cluster name. If null, project-environment-eks is used."
  type        = string
  default     = null
}

variable "project" {
  description = "Project tag and naming prefix."
  type        = string
}

variable "environment" {
  description = "Environment tag and policy context."
  type        = string
}

variable "owner" {
  description = "Owner tag value."
  type        = string
}

variable "tags" {
  description = "Additional tags merged into supported resources."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID where the private EKS endpoint and worker nodes run."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS control plane attachment and managed node groups."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "EKS requires at least two private subnets for high availability."
  }
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version."
  type        = string
  default     = "1.30"
}

variable "authentication_mode" {
  description = "EKS access authentication mode."
  type        = string
  default     = "API_AND_CONFIG_MAP"
}

variable "enabled_cluster_log_types" {
  description = "EKS control plane log types."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "cluster_log_retention_days" {
  description = "CloudWatch retention for EKS control plane logs."
  type        = number
  default     = 365
}

variable "enable_cluster_log_kms_key" {
  description = "Associate the EKS control plane CloudWatch log group with the cluster KMS key. Disable only for emulators that do not support AssociateKmsKey."
  type        = bool
  default     = true
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

variable "kms_deletion_window_in_days" {
  description = "Deletion window for the EKS KMS key."
  type        = number
  default     = 30
}

variable "node_egress_cidr_blocks" {
  description = "CIDR blocks allowed for node egress."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "create_node_ingress_security_group_rules" {
  description = "Create ingress security group rules between EKS cluster and node security groups. Keep enabled for AWS; disable only for emulators that cannot read these rule IDs back."
  type        = bool
  default     = true
}

variable "create_node_egress_security_group_rule" {
  description = "Create the node security group egress rule."
  type        = bool
  default     = true
}

variable "create_managed_node_groups" {
  description = "Create AWS managed EKS node groups. Keep enabled for AWS; disable only for emulators that do not support CreateNodegroup."
  type        = bool
  default     = true
}

variable "create_self_managed_node_groups" {
  description = "Create self-managed EKS worker capacity with EC2 Launch Templates and Auto Scaling Groups."
  type        = bool
  default     = false
}

variable "create_floci_node_group_placeholders" {
  description = "Create Terraform-only node group placeholders for Floci emulator runs where node group APIs are unavailable."
  type        = bool
  default     = false
}

variable "self_managed_node_ami_id" {
  description = "AMI ID used by self-managed node groups. For AWS, use an EKS optimized AMI."
  type        = string
  default     = "ami-0abcdef1234567890"
}

variable "create_cluster_addons" {
  description = "Create EKS managed addons. Keep enabled for AWS; disable only for emulators that do not support addon APIs."
  type        = bool
  default     = true
}

variable "node_groups" {
  description = "Managed node groups keyed by workload purpose."
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

  default = {
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

  validation {
    condition = alltrue([
      for node_group in values(var.node_groups) :
      node_group.desired_size >= 2 && node_group.min_size >= 2 && node_group.max_size >= node_group.desired_size
    ])
    error_message = "Every EKS node group must have min_size >= 2, desired_size >= 2, and max_size >= desired_size."
  }
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
