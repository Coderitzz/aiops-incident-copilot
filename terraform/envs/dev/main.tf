locals {
  name = "${var.project}-${var.environment}"
}

module "vpc" {
  source             = "../../modules/vpc"
  name               = local.name
  cidr_block         = var.vpc_cidr
  az_count           = 2
  enable_nat_gateway = var.enable_nat_gateway
}

module "security_groups" {
  source     = "../../modules/security_groups"
  name       = local.name
  vpc_id     = module.vpc.vpc_id
  admin_cidr = var.admin_cidr
}

module "iam" {
  source = "../../modules/iam"
  name   = local.name
}

module "ecr" {
  source       = "../../modules/ecr"
  name_prefix  = var.project
  repositories = var.ecr_repositories
}

resource "aws_key_pair" "this" {
  key_name   = "${local.name}-key"
  public_key = file(pathexpand(var.public_key_path))
}

# Latest Ubuntu 24.04 LTS AMI, published by Canonical in SSM Parameter Store
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

module "hosts" {
  source   = "../../modules/ec2"
  for_each = var.instances

  name                  = "${local.name}-${each.key}"
  role                  = each.key
  ami_id                = nonsensitive(data.aws_ssm_parameter.ubuntu_ami.value)
  instance_type         = each.value.instance_type
  volume_gb             = each.value.volume_gb
  public                = each.value.public
  subnet_id             = each.value.public ? module.vpc.public_subnet_ids[0] : module.vpc.private_subnet_ids[0]
  security_group_ids    = [each.value.public ? module.security_groups.bastion_sg_id : module.security_groups.private_sg_id]
  key_name              = aws_key_pair.this.key_name
  instance_profile_name = module.iam.instance_profile_name
}
