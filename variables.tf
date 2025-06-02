# Remote State Configuration
variable "tfc_organization" {
  description = "Terraform Cloud organization name"
  type        = string
}

variable "infrastructure_workspace_name" {
  description = "Name of the infrastructure workspace in Terraform Cloud"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
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
