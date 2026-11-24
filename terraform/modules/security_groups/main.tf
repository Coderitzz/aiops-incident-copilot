variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "admin_cidr" {
  description = "Your public IP in CIDR form, the only address allowed to SSH to the bastion"
  type        = string
}

# --- Bastion: the only host reachable from the internet ---
resource "aws_security_group" "bastion" {
  name_prefix = "${var.name}-bastion-"
  description = "Bastion host"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-bastion-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Private hosts: CI box and k3s node ---
resource "aws_security_group" "private" {
  name_prefix = "${var.name}-private-"
  description = "Private hosts"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-private-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

# Separate rule resources avoid a dependency cycle between the two groups.
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_admin" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH from admin IP"
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "bastion_node_exporter" {
  security_group_id            = aws_security_group.bastion.id
  description                  = "Prometheus scrapes node_exporter from private hosts"
  referenced_security_group_id = aws_security_group.private.id
  from_port                    = 9100
  to_port                      = 9100
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "private_ssh_bastion" {
  security_group_id            = aws_security_group.private.id
  description                  = "SSH from bastion only"
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "private_self" {
  security_group_id            = aws_security_group.private.id
  description                  = "All traffic between private hosts (k3s, Jenkins, metrics)"
  referenced_security_group_id = aws_security_group.private.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "bastion_all" {
  security_group_id = aws_security_group.bastion.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "private_all" {
  security_group_id = aws_security_group.private.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}

output "private_sg_id" {
  value = aws_security_group.private.id
}
