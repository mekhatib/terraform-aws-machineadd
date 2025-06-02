output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = module.ec2_instances.instance_ids
}

output "instance_private_ips" {
  description = "Private IPs of the EC2 instances"
  value       = module.ec2_instances.private_ips
}
