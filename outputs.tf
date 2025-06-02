# Add-on outputs.tf - Comprehensive Information and Debug Data

# ================================
# DISCOVERY INFORMATION
# ================================

output "discovery_details" {
  description = "Details about the smart discovery process"
  value = {
    current_workspace       = terraform.workspace
    detected_parent        = local.detected_parent_workspace
    parent_candidates      = local.parent_workspace_candidates
    found_tenant_workspace = local.tenant_workspace_name
    discovery_successful   = local.has_required_infrastructure
    discovery_method       = "parent-based-smart-discovery"
    available_workspaces   = keys(local.all_workspaces)
    tenant_organization    = local.tenant_tfc_org
  }
}

# ================================
# INSTANCE INFORMATION
# ================================

output "instances" {
  description = "Complete information about created instances"
  value = local.has_required_infrastructure ? {
    for i, instance in aws_instance.compute : "instance-${i + 1}" => {
      id               = instance.id
      name            = "${local.detected_parent_workspace}-${var.environment}-instance-${i + 1}"
      private_ip       = instance.private_ip
      public_ip        = instance.public_ip
      availability_zone = instance.availability_zone
      subnet_id        = instance.subnet_id
      instance_type    = instance.instance_type
      state           = instance.instance_state
      key_name        = instance.key_name
      security_groups = instance.vpc_security_group_ids
      elastic_ip      = var.assign_elastic_ips ? aws_eip.instance_eips[i].public_ip : null
    }
  } : {}
}

output "instance_ids" {
  description = "List of EC2 instance IDs"
  value       = local.has_required_infrastructure ? aws_instance.compute[*].id : []
}

output "instance_names" {
  description = "List of instance names"
  value = local.has_required_infrastructure ? [
    for i in range(var.instance_count) : "${local.detected_parent_workspace}-${var.environment}-instance-${i + 1}"
  ] : []
}

output "private_ips" {
  description = "List of private IP addresses"
  value       = local.has_required_infrastructure ? aws_instance.compute[*].private_ip : []
}

output "public_ips" {
  description = "List of public IP addresses"
  value       = local.has_required_infrastructure ? aws_instance.compute[*].public_ip : []
}

output "elastic_ips" {
  description = "List of Elastic IP addresses (if assigned)"
  value       = var.assign_elastic_ips && local.has_required_infrastructure ? aws_eip.instance_eips[*].public_ip : []
}

# ================================
# ACCESS INFORMATION
# ================================

output "access_info" {
  description = "Information for accessing and managing instances"
  value = local.has_required_infrastructure ? {
    key_pair_name    = aws_key_pair.instance_key[0].key_name
    iam_role_name    = aws_iam_role.instance_role[0].name
    instance_profile = aws_iam_instance_profile.instance_profile[0].name
    security_groups  = [local.app_sg_id, local.base_sg_id]
  } : {}
}

output "ssh_commands" {
  description = "SSH commands to connect to instances"
  value = local.has_required_infrastructure ? {
    for i, instance in aws_instance.compute : "instance-${i + 1}" => {
      command = "ssh -i ${aws_key_pair.instance_key[0].key_name}.pem ec2-user@${instance.public_ip != "" ? instance.public_ip : instance.private_ip}"
      ip_type = instance.public_ip != "" ? "public" : "private"
      target_ip = instance.public_ip != "" ? instance.public_ip : instance.private_ip
    }
  } : {}
}

output "ssm_session_commands" {
  description = "AWS SSM Session Manager commands to connect to instances"
  value = local.has_required_infrastructure ? {
    for i, instance in aws_instance.compute : "instance-${i + 1}" => 
    "aws ssm start-session --target ${instance.id} --region ${var.aws_region}"
  } : {}
}

# ================================
# INFRASTRUCTURE CONTEXT
# ================================

output "infrastructure_context" {
  description = "Context about the tenant infrastructure used"
  value = {
    parent_workspace   = local.detected_parent_workspace
    tenant_workspace   = local.tenant_workspace
    organization       = local.tenant_tfc_org
    vpc_id            = local.vpc_id
    subnet_ids        = local.subnet_ids
    security_groups   = {
      app  = local.app_sg_id
      base = local.base_sg_id
    }
    ipam_pool_id      = local.ipam_pool_id
    transit_gateway_id = local.transit_gateway_id
    aws_region        = var.aws_region
  }
}

output "network_configuration" {
  description = "Network configuration details"
  value = {
    vpc_id             = local.vpc_id
    subnet_ids         = local.subnet_ids
    subnet_count       = length(local.subnet_ids)
    security_group_ids = compact([local.app_sg_id, local.base_sg_id])
    public_subnets     = var.assign_public_ip
    elastic_ips        = var.assign_elastic_ips
  }
}

# ================================
# WORKSPACE RELATIONSHIP
# ================================

output "workspace_relationship" {
  description = "Relationship between workspaces"
  value = {
    current_workspace = terraform.workspace
    parent_workspace  = local.detected_parent_workspace
    tenant_workspace  = local.tenant_workspace
    relationship_type = "add-on-to-parent"
    naming_pattern   = "parent-based-discovery"
    workspace_chain  = [local.tenant_workspace, terraform.workspace]
  }
}

# ================================
# DEPLOYMENT SUMMARY
# ================================

output "deployment_summary" {
  description = "Summary of the deployment"
  value = {
    # Discovery
    discovery_method     = "smart-parent-based"
    parent_workspace     = local.detected_parent_workspace
    tenant_workspace     = local.tenant_workspace
    discovery_successful = local.has_required_infrastructure
    
    # Resources
    instances_created    = local.has_required_infrastructure ? var.instance_count : 0
    instance_type       = var.instance_type
    root_volume_size    = var.root_volume_size
    elastic_ips         = var.assign_elastic_ips
    public_ips          = var.assign_public_ip
    
    # Configuration
    environment         = var.environment
    project_name       = var.project_name
    aws_region         = var.aws_region
    
    # Metadata
    deployment_time     = timestamp()
    terraform_version   = null  # Will be filled by Terraform
    infrastructure_valid = local.has_required_infrastructure
  }
}

# ================================
# TROUBLESHOOTING INFORMATION
# ================================

output "troubleshooting_info" {
  description = "Information for troubleshooting discovery or deployment issues"
  value = {
    current_workspace     = terraform.workspace
    parent_candidates     = local.parent_workspace_candidates
    all_workspaces       = keys(local.all_workspaces)
    tenant_found         = local.tenant_workspace_name != null
    infrastructure_valid = local.has_required_infrastructure
    
    # What was found/not found
    vpc_id_found        = local.vpc_id != ""
    subnets_found       = length(local.subnet_ids) > 0
    security_groups_found = local.app_sg_id != "" && local.base_sg_id != ""
    
    # Suggestions
    manual_override_var = "
