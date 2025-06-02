# Infrastructure outputs as inputs
variable "vpc_id" {
  description = "VPC ID from infrastructure module"
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block from infrastructure module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs from infrastructure module"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs from infrastructure module"
  type        = list(string)
}

variable "all_subnet_ids" {
  description = "All subnet IDs from infrastructure module"
  type        = list(string)
}

variable "app_security_group_id" {
  description = "Application security group ID from infrastructure module"
  type        = string
}

variable "instance_role_name" {
  description = "IAM instance role name from infrastructure module"
  type        = string
}

variable "common_tags" {
  description = "Common tags from infrastructure module"
  type        = map(string)
}

variable "environment" {
  description = "Environment name from infrastructure module"
  type        = string
}

variable "project_name" {
  description = "Project name from infrastructure module"
  type        = string
}

variable "aws_region" {
  description = "AWS region from infrastructure module"
  type        = string
}

# Compute-specific variables
variable "instance_types" {
  description = "Instance types for different flavors"
  type        = map(string)
  default = {
    flavor1 = "t3.micro"
    flavor2 = "t3.small"
  }
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "assign_elastic_ips" {
  description = "Whether to assign Elastic IPs to instances"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for instances"
  type        = bool
  default     = false
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization threshold for CloudWatch alarms"
  type        = number
  default     = 80
}
