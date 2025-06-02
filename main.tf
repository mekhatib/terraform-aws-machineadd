# IAM Roles Module
module "iam_roles" {
  source  = "app.terraform.io/test-khatib/iam-roles/aws"
  version = "~> 0.0"
  
  environment  = var.environment
  project_name = var.project_name
  
  # Add AWS managed policies for SSM and CloudWatch
  managed_policies = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
  
  # Enable EC2 operations (already default true)
  enable_ec2_operations = true
  
  tags = local.common_tags
}

# Create key pair
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-${var.environment}-keypair"
  public_key = tls_private_key.main.public_key_openssh
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-keypair"
    }
  )
}

# EC2 Instances Module
module "ec2_instances" {
  source  = "app.terraform.io/test-khatib/ec2-instances/aws"
  version = "~> 0.0"
  
  environment  = var.environment
  project_name = var.project_name
  
  # The module expects a list of instance configurations
  instances = [
    {
      name               = "${var.project_name}-${var.environment}-instance-1"
      instance_type      = var.instance_types["flavor1"]
      subnet_id          = length(module.vpc.private_subnet_ids) > 0 ? module.vpc.private_subnet_ids[0] : module.vpc.subnet_ids[0]
      security_group_ids = [module.security_groups.app_sg_id]
      iam_role_name      = module.iam_roles.instance_role_name
      user_data_file     = null
      tags               = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-instance-1" })
    },
    {
      name               = "${var.project_name}-${var.environment}-instance-2"
      instance_type      = var.instance_types["flavor2"]
      subnet_id          = length(module.vpc.private_subnet_ids) > 1 ? module.vpc.private_subnet_ids[1] : (length(module.vpc.subnet_ids) > 1 ? module.vpc.subnet_ids[1] : module.vpc.subnet_ids[0])
      security_group_ids = [module.security_groups.app_sg_id]
      iam_role_name      = module.iam_roles.instance_role_name
      user_data_file     = null
      tags               = merge(local.common_tags, { Name = "${var.project_name}-${var.environment}-instance-2" })
    }
  ]
  
  # Other required/optional parameters
  ami_id                   = data.aws_ami.amazon_linux.id
  key_name                 = aws_key_pair.main.key_name
  root_volume_size         = 20
  assign_elastic_ips       = true
  elastic_ip_allocation_ids = []  # Let module create new EIPs
  create_dns_records       = false  # Disable since no Route53 zone available
  route53_zone_id          = null  # VPC module doesn't create Route53 zone
  route53_zone_name        = "${var.project_name}-${var.environment}.internal"
  enable_monitoring        = false
  cpu_alarm_threshold      = 80
  alarm_actions           = []  # Will be populated if monitoring module provides SNS topic
  create_instance_profiles = true  # We're using IAM roles from iam_roles module
  additional_volumes      = []
  kms_key_id              = null
  
  # Ensure all dependencies are created first
  depends_on = [
    module.vpc,
    module.security_groups,
    module.iam_roles,
    aws_key_pair.main
  ]
}

# Add cleanup dependency resource to ensure proper destroy order
resource "null_resource" "destroy_order" {
  depends_on = [
    module.ec2_instances,
    module.transit_gateway,
    module.security_groups,
    module.vpc,
    module.ipam
  ]
  
  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Infrastructure destroyed in proper order'"
  }
}
