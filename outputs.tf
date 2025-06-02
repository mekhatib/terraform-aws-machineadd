output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = module.ec2_instances.instance_ids
}

output "instance_private_ips" {
  description = "Private IPs of the EC2 instances"
  value       = module.ec2_instances.private_ips
}

output "key_pair_name" {
  description = "Name of the created key pair"
  value       = aws_key_pair.main.key_name
}

output "private_key_pem" {
  description = "Private key in PEM format (sensitive)"
  value       = tls_private_key.main.private_key_pem
  sensitive   = true
}

# Simplified outputs without data sources
output "instance_details" {
  description = "Basic instance information"
  value = {
    for idx, id in module.ec2_instances.instance_ids : 
      "${var.project_name}-${var.environment}-instance-${idx + 1}" => {
        instance_id = id
        private_ip  = module.ec2_instances.private_ips[idx]
      }
  }
}

# Note about public IPs
output "public_ip_note" {
  description = "Information about accessing public IPs"
  value       = "To view public IPs, use: aws ec2 describe-instances --instance-ids ${join(" ", module.ec2_instances.instance_ids)} --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress]' --output table"
}

# SSH connection helper
output "ssh_connection_helper" {
  description = "Helper information for SSH connections"
  value = {
    key_location = "Save the private key to a file and chmod 400",
    username     = "ec2-user (for Amazon Linux)",
    connect_via  = var.assign_elastic_ips ? "Use public IP from AWS Console or CLI" : "Use SSM Session Manager or bastion host"
  }
}
