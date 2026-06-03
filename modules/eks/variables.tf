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
