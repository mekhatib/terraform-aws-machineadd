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

  owners = ["amazon"]
}

# Data sources to fetch instance details including public IPs
data "aws_instance" "instances" {
  for_each = toset(module.ec2_instances.instance_ids)
  
  instance_id = each.value
  
  depends_on = [module.ec2_instances]
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
    var.common_tags,
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
  
  instances = [
    {
      name               = "${var.project_name}-${var.environment}-instance-1"
      instance_type      = var.instance_types["flavor1"]
      subnet_id          = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids[0] : var.all_subnet_ids[0]
      security_group_ids = [var.app_security_group_id]
      iam_role_name      = var.instance_role_name
      user_data_file     = null
      tags               = merge(var.common_tags, { Name = "${var.project_name}-${var.environment}-instance-1" })
    },
    {
      name               = "${var.project_name}-${var.environment}-instance-2"
      instance_type      = var.instance_types["flavor2"]
      subnet_id          = length(var.private_subnet_ids) > 1 ? var.private_subnet_ids[1] : (length(var.all_subnet_ids) > 1 ? var.all_subnet_ids[1] : var.all_subnet_ids[0])
      security_group_ids = [var.app_security_group_id]
      iam_role_name      = var.instance_role_name
      user_data_file     = null
      tags               = merge(var.common_tags, { Name = "${var.project_name}-${var.environment}-instance-2" })
    }
  ]
  
  ami_id                    = data.aws_ami.amazon_linux.id
  key_name                  = aws_key_pair.main.key_name
  root_volume_size          = var.root_volume_size
  assign_elastic_ips        = var.assign_elastic_ips
  elastic_ip_allocation_ids = []
  create_dns_records        = false
  route53_zone_id          = null
  route53_zone_name        = "${var.project_name}-${var.environment}.internal"
  enable_monitoring        = var.enable_monitoring
  cpu_alarm_threshold      = var.cpu_alarm_threshold
  alarm_actions           = []
  create_instance_profiles = true
  additional_volumes      = []
  kms_key_id              = null
  
  depends_on = [
    aws_key_pair.main
  ]
}
