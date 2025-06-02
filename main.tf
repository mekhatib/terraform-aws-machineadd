# environments/dev/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.49"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"] # Amazon's official AMIs
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}



# Get all workspaces in the organization for smart discovery
data "tfe_workspace_ids" "all_workspaces" {
  names        = ["*"]
  organization = var.tfc_organization
}

# Smart discovery using current workspace context
locals {
  # Get current workspace name
  current_workspace = terraform.workspace
  
  # Extract parent workspace name from current workspace using multiple patterns
  parent_workspace_candidates = compact([
    # Remove common add-on suffixes
    try(regex("^(.+)-(compute|addon|ec2|app)(-.*)?$", local.current_workspace)[0], null),
    try(regex("^(.+)-compute$", local.current_workspace)[0], null),
    try(regex("^(.+)-addon$", local.current_workspace)[0], null),
    try(regex("^(.+)-ec2$", local.current_workspace)[0], null),
    try(regex("^(.+)-app$", local.current_workspace)[0], null),
    
    # Remove version suffixes like -v1, -v2
    try(regex("^(.+)-v[0-9]+$", local.current_workspace)[0], null),
    
    # Remove environment suffixes if present in current workspace
    try(regex("^(.+)-${var.environment}$", local.current_workspace)[0], null),
    try(regex("^(.+)-(dev|staging|prod|test)$", local.current_workspace)[0], null),
    
    # Try removing last segment
    try(join("-", slice(split("-", local.current_workspace), 0, length(split("-", local.current_workspace)) - 1)), null),
    
    # Try removing last two segments
    try(join("-", slice(split("-", local.current_workspace), 0, max(1, length(split("-", local.current_workspace)) - 2))), null)
  ])
  
  # Get all potential tenant workspaces
  all_workspaces = data.tfe_workspace_ids.all_workspaces.ids
  
  # Find tenant workspace using intelligent parent-based discovery
  tenant_workspace_name = try(
    # Method 1: Direct parent workspace name match
    contains(keys(local.all_workspaces), local.parent_workspace_candidates[0]) ? local.parent_workspace_candidates[0] : null,
    
    # Method 2: Try each parent candidate
    [for candidate in local.parent_workspace_candidates : candidate if contains(keys(local.all_workspaces), candidate)][0],
    
    # Method 3: Parent with common infrastructure suffixes
    [for candidate in local.parent_workspace_candidates : 
     for suffix in ["", "-infrastructure", "-infra", "-tenant", "-base"] :
     "${candidate}${suffix}" if contains(keys(local.all_workspaces), "${candidate}${suffix}")][0],
    
    # Method 4: Look for workspaces that start with parent candidates
    [for candidate in local.parent_workspace_candidates :
     for ws_name in keys(local.all_workspaces) :
     ws_name if startswith(ws_name, candidate) && 
                ws_name != local.current_workspace &&
                !can(regex("(compute|addon|ec2|app)", ws_name))][0],
    
    # Method 5: Reverse lookup - find workspaces where current could be a child
    [for ws_name in keys(local.all_workspaces) :
     ws_name if startswith(local.current_workspace, ws_name) && 
                ws_name != local.current_workspace &&
                !can(regex("(compute|addon|ec2|app)", ws_name))][0],
    
    # Method 6: Fallback to project-based discovery
    lookup(local.all_workspaces, "${var.project_name}-infrastructure", null),
    lookup(local.all_workspaces, "${var.project_name}-infra", null),
    lookup(local.all_workspaces, var.project_name, null),
    
    # Method 7: Manual override
    var.tenant_workspace_name_override
  )
  
  # Extract the most likely parent workspace name
  detected_parent_workspace = length(local.parent_workspace_candidates) > 0 ? local.parent_workspace_candidates[0] : var.project_name
}

# Get tenant infrastructure outputs with validation
data "terraform_remote_state" "tenant" {
  count = local.tenant_workspace_name != null ? 1 : 0
  
  backend = "remote"
  config = {
    organization = var.tfc_organization
    workspaces = {
      name = local.tenant_workspace_name
    }
  }
  
  # Validation using postcondition (HCP Terraform compatible)
  lifecycle {
    postcondition {
      condition = self.outputs != null
      error_message = <<-EOT
        ❌ Failed to connect to tenant workspace: ${local.tenant_workspace_name}
        
        Discovery Details:
        - Current workspace: ${local.current_workspace}
        - Parent candidates: ${join(", ", local.parent_workspace_candidates)}
        - Found tenant: ${local.tenant_workspace_name}
        - Available workspaces: ${join(", ", slice(keys(local.all_workspaces), 0, min(10, length(keys(local.all_workspaces)))))}
        
        Check that the tenant workspace exists and has outputs.
      EOT
    }
    
    postcondition {
      condition = can(self.outputs.vpc_id) && can(self.outputs.subnet_ids) && can(self.outputs.security_group_ids)
      error_message = <<-EOT
        ❌ Tenant workspace ${local.tenant_workspace_name} missing required outputs.
        
        Required outputs: vpc_id, subnet_ids, security_group_ids
        Available outputs: ${join(", ", keys(self.outputs))}
        
        Ensure your tenant workspace exports the necessary infrastructure outputs.
      EOT
    }
  }
}

# Extract tenant infrastructure values
locals {
  # Check if we have valid tenant data
  has_tenant_data = length(data.terraform_remote_state.tenant) > 0
  
  # Network infrastructure from tenant (with safe fallbacks)
  vpc_id     = local.has_tenant_data ? data.terraform_remote_state.tenant[0].outputs.vpc_id : ""
  subnet_ids = local.has_tenant_data ? data.terraform_remote_state.tenant[0].outputs.subnet_ids : []
  
  # Security groups from tenant
  security_group_ids = local.has_tenant_data ? data.terraform_remote_state.tenant[0].outputs.security_group_ids : {}
  app_sg_id         = try(local.security_group_ids.app, "")
  base_sg_id        = try(local.security_group_ids.base, "")
  
  # Other infrastructure from tenant
  ipam_pool_id       = local.has_tenant_data ? try(data.terraform_remote_state.tenant[0].outputs.ipam_pool_id, "") : ""
  transit_gateway_id = local.has_tenant_data ? try(data.terraform_remote_state.tenant[0].outputs.transit_gateway_id, "") : ""
  
  # Workspace info
  tenant_tfc_org     = local.has_tenant_data ? try(data.terraform_remote_state.tenant[0].outputs.tfc_organization, var.tfc_organization) : var.tfc_organization
  tenant_workspace   = local.has_tenant_data ? try(data.terraform_remote_state.tenant[0].outputs.workspace_name, local.tenant_workspace_name) : local.tenant_workspace_name
  
  # Validation - check if we have the minimum required infrastructure
  has_required_infrastructure = local.vpc_id != "" && length(local.subnet_ids) > 0 && local.app_sg_id != ""
  
  # Tags with discovery context
  common_tags = {
    Environment         = var.environment
    Project            = var.project_name
    ManagedBy          = "Terraform"
    Owner              = var.owner_email
    CostCenter         = var.cost_center
    Workload           = "compute"
    TenantWorkspace    = local.tenant_workspace
    ParentWorkspace    = local.detected_parent_workspace
    CurrentWorkspace   = local.current_workspace
    DiscoveryMethod    = "parent-based-smart-discovery"
  }
}

# Validation checks using HCP Terraform compatible check blocks
check "workspace_discovery" {
  assert {
    condition = local.tenant_workspace_name != null
    error_message = <<-EOT
      ❌ Tenant workspace discovery failed!
      
      Current workspace: ${local.current_workspace}
      Parent candidates: ${join(", ", local.parent_workspace_candidates)}
      Available workspaces: ${join(", ", keys(local.all_workspaces))}
      
      Solutions:
      1. Set tenant_workspace_name_override variable
      2. Ensure tenant workspace exists with proper naming
      3. Check workspace naming follows parent-child pattern
    EOT
  }
}

check "infrastructure_requirements" {
  assert {
    condition = local.has_required_infrastructure || local.tenant_workspace_name == null
    error_message = <<-EOT
      ❌ Required infrastructure not found in tenant workspace!
      
      Tenant workspace: ${local.tenant_workspace_name}
      VPC ID: ${local.vpc_id}
      Subnet count: ${length(local.subnet_ids)}
      App Security Group: ${local.app_sg_id}
      
      Ensure tenant workspace has vpc_id, subnet_ids, and security_group_ids outputs.
    EOT
  }
}

# Get latest Amazon Linux AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create key pair for instances
resource "tls_private_key" "instance_key" {
  count = local.has_required_infrastructure ? 1 : 0
  
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "instance_key" {
  count = local.has_required_infrastructure ? 1 : 0
  
  key_name   = "${local.detected_parent_workspace}-${var.environment}-compute-key"
  public_key = tls_private_key.instance_key[0].public_key_openssh
  
  tags = merge(local.common_tags, {
    Name = "${local.detected_parent_workspace}-${var.environment}-compute-key"
  })
}

# IAM role for EC2 instances
resource "aws_iam_role" "instance_role" {
  count = local.has_required_infrastructure ? 1 : 0
  
  name = "${local.detected_parent_workspace}-${var.environment}-compute-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.common_tags
}

# Attach policies to IAM role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  count = local.has_required_infrastructure ? 1 : 0
  
  role       = aws_iam_role.instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  count = local.has_required_infrastructure ? 1 : 0
  
  role       = aws_iam_role.instance_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Create instance profile
resource "aws_iam_instance_profile" "instance_profile" {
  count = local.has_required_infrastructure ? 1 : 0
  
  name = "${local.detected_parent_workspace}-${var.environment}-compute-profile"
  role = aws_iam_role.instance_role[0].name
  
  tags = local.common_tags
}

# EC2 instances using discovered tenant infrastructure
resource "aws_instance" "compute" {
  count = local.has_required_infrastructure ? var.instance_count : 0
  
  ami                         = data.aws_ami.amazon_linux.id
  instance_type              = var.instance_type
  subnet_id                  = local.subnet_ids[count.index % length(local.subnet_ids)]
  vpc_security_group_ids     = compact([local.app_sg_id, local.base_sg_id])
  key_name                   = aws_key_pair.instance_key[0].key_name
  iam_instance_profile       = aws_iam_instance_profile.instance_profile[0].name
  associate_public_ip_address = var.assign_public_ip
  
  root_block_device {
    volume_type = var.root_volume_type
    volume_size = var.root_volume_size
    encrypted   = var.encrypt_volumes
    
    tags = merge(local.common_tags, {
      Name = "${local.detected_parent_workspace}-${var.environment}-instance-${count.index + 1}-root"
    })
  }
  
  # User data for basic setup
  user_data = base64encode(templatestring(var.user_data_template, {
    hostname         = "${local.detected_parent_workspace}-${var.environment}-${count.index + 1}"
    project_name     = var.project_name
    environment      = var.environment
    instance_num     = count.index + 1
    parent_workspace = local.detected_parent_workspace
    tenant_workspace = local.tenant_workspace
  }))
  
  tags = merge(local.common_tags, {
    Name = "${local.detected_parent_workspace}-${var.environment}-instance-${count.index + 1}"
    Type = "compute"
  })
  
  depends_on = [aws_iam_instance_profile.instance_profile]
}

# Elastic IPs (optional)
resource "aws_eip" "instance_eips" {
  count = var.assign_elastic_ips && local.has_required_infrastructure ? var.instance_count : 0
  
  instance = aws_instance.compute[count.index].id
  domain   = "vpc"
  
  tags = merge(local.common_tags, {
    Name = "${local.detected_parent_workspace}-${var.environment}-eip-${count.index + 1}"
  })
  
  depends_on = [aws_instance.compute]
}
