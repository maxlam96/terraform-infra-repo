variable "aws_region" {
  description = "AWS-compatible region used by Floci."
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Environment tag and policy context."
  type        = string
  default     = "staging"
}

variable "floci_endpoint" {
  description = "Remote Floci AWS-compatible endpoint."
  type        = string
  default     = "http://192.168.251.1:4566"
}

variable "project" {
  description = "Project name used in names and tags."
  type        = string
  default     = "floci-vpc-lab"
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.40.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private application subnet."
  type        = string
  default     = "10.40.2.0/24"
}

variable "db_subnet_cidr" {
  description = "CIDR block for the database subnet."
  type        = string
  default     = "10.40.3.0/24"
}
