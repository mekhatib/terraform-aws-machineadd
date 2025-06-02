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

# Additional outputs if needed
output "instance_details" {
  description = "Map of instance names to their IDs"
  value = {
    for i, id in module.ec2_instances.instance_ids : 
      "${var.project_name}-${var.environment}-instance-${i + 1}" => id
  }
}
