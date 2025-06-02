output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = module.ec2_instances.instance_ids
}

output "instance_private_ips" {
  description = "Private IPs of the EC2 instances"
  value       = module.ec2_instances.private_ips
}

output "instance_public_ips" {
  description = "Public IPs of the EC2 instances"
  value       = [for instance in data.aws_instance.instances : instance.public_ip]
}

output "instance_public_dns" {
  description = "Public DNS names of the EC2 instances"
  value       = [for instance in data.aws_instance.instances : instance.public_dns]
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
  description = "Detailed information about each instance"
  value = {
    for idx, id in module.ec2_instances.instance_ids : 
      "${var.project_name}-${var.environment}-instance-${idx + 1}" => {
        instance_id = id
        private_ip  = module.ec2_instances.private_ips[idx]
        public_ip   = data.aws_instance.instances[id].public_ip
        public_dns  = data.aws_instance.instances[id].public_dns
      }
  }
}

output "instance_connection_info" {
  description = "SSH connection information for instances"
  value = {
    for idx, id in module.ec2_instances.instance_ids : 
      "${var.project_name}-${var.environment}-instance-${idx + 1}" => {
        ssh_command = data.aws_instance.instances[id].public_ip != "" ? "ssh -i <private_key_file> ec2-user@${data.aws_instance.instances[id].public_ip}" : "Instance has no public IP - use SSM or bastion host"
      }
  }
}
