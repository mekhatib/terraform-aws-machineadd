# Add-on variables.tf - Smart Discovery with Minimal Configuration

# ================================
# DISCOVERY CONFIGURATION
# ================================

variable "tfc_organization" {
  description = "Terraform Cloud organization name"
  type        = string
  default     = "test-khatib"
}

variable "project_name" {
  description = "Project name (used for workspace discovery fallback)"
  type        = string
  default     = "netlevel"
}

variable "environment" {
  description = "Environment name (used in resource naming and discovery)"
  type        = string
  default     = "dev"
}

# ================================
# OPTIONAL OVERRIDE (Troubleshooting)
# ================================

variable "tenant_workspace_name_override" {
  description = "Manual override for tenant workspace name (only use if auto-discovery fails)"
  type        = string
  default     = null
}

# ================================
# AWS CONFIGURATION
# ================================

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "owner_email" {
  description = "Email of the resource owner"
  type        = string
  default     = "admin@company.com"
}

variable "cost_center" {
  description = "Cost center for billing and tagging"
  type        = string
  default     = "shared"
}

# ================================
# EC2 INSTANCE CONFIGURATION
# ================================

variable "instance_count" {
  description = "Number of EC2 instances to create"
  type        = number
  default     = 2
  
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 20
    error_message = "Instance count must be between 1 and 20."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition = contains([
      "t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge",
      "t3a.micro", "t3a.small", "t3a.medium", "t3a.large", "t3a.xlarge",
      "m5.large", "m5.xlarge", "m5.2xlarge",
      "c5.large", "c5.xlarge", "c5.2xlarge",
      "r5.large", "r5.xlarge"
    ], var.instance_type)
    error_message = "Instance type must be a supported type."
  }
}

# ================================
# STORAGE CONFIGURATION
# ================================

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 1000
    error_message = "Root volume size must be between 8 and 1000 GB."
  }
}

variable "root_volume_type" {
  description = "Type of the root EBS volume"
  type        = string
  default     = "gp3"
  
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume_type)
    error_message = "Root volume type must be gp2, gp3, io1, or io2."
  }
}

variable "encrypt_volumes" {
  description = "Encrypt EBS volumes"
  type        = bool
  default     = true
}

# ================================
# NETWORKING CONFIGURATION
# ================================

variable "assign_public_ip" {
  description = "Assign public IP addresses to instances"
  type        = bool
  default     = false
}

variable "assign_elastic_ips" {
  description = "Create and assign Elastic IP addresses to instances"
  type        = bool
  default     = false
}

# ================================
# USER DATA CONFIGURATION
# ================================

variable "user_data_template" {
  description = "User data template for instance initialization"
  type        = string
  default     = <<-EOF
    #!/bin/bash
    
    # Update system
    yum update -y
    
    # Install useful packages
    yum install -y \
        htop \
        tree \
        wget \
        curl \
        git \
        unzip \
        vim \
        jq \
        awscli
    
    # Set hostname
    hostnamectl set-hostname ${hostname}
    
    # Install and configure SSM agent
    yum install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
    # Install CloudWatch agent
    wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
    rpm -U ./amazon-cloudwatch-agent.rpm
    
    # Create welcome message
    cat > /etc/motd << 'MOTD'
===========================================
${project_name} ${environment} - Instance ${instance_num}
===========================================
Hostname: ${hostname}
Parent Workspace: ${parent_workspace}
Tenant Workspace: ${tenant_workspace}
Managed by: Waypoint Add-on (Smart Discovery)
===========================================
MOTD
    
    # Create logs directory
    mkdir -p /var/log/waypoint
    
    # Log completion with discovery context
    cat >> /var/log/waypoint/deployment.log << LOG
$(date): User data script completed successfully
$(date): Hostname: ${hostname}
$(date): Project: ${project_name}
$(date): Environment: ${environment}
$(date): Instance Number: ${instance_num}
$(date): Parent Workspace: ${parent_workspace}
$(date): Tenant Workspace: ${tenant_workspace}
$(date): Deployment Method: Waypoint Add-on with Smart Discovery
LOG
    
    # Set up basic monitoring
    echo "* * * * * root /usr/bin/aws cloudwatch put-metric-data --namespace 'Custom/EC2' --metric-data MetricName=InstanceHealth,Value=1,Unit=Count --region $(curl -s http://169.254.169.254/latest/meta-data/placement/region)" > /etc/cron.d/health-check
    
    # Signal completion
    echo "$(date): Instance ${hostname} initialization completed" >> /var/log/waypoint/deployment.log
  EOF
}

# ================================
# OPTIONAL ADVANCED CONFIGURATION
# ================================

variable "additional_security_group_ids" {
  description = "Additional security group IDs to attach to instances"
  type        = list(string)
  default     = []
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for instances"
  type        = bool
  default     = false
}

variable "instance_metadata_options" {
  description = "Instance metadata service options"
  type = object({
    http_endpoint = string
    http_tokens   = string
    hop_limit     = number
  })
  default = {
    http_endpoint = "enabled"
    http_tokens   = "required"
    hop_limit     = 1
  }
}
