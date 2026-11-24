variable "name" {
  type = string
}

variable "role" {
  description = "Value of the Role tag; Ansible builds inventory groups from it"
  type        = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "key_name" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "public" {
  description = "Give the instance a public IP"
  type        = bool
  default     = false
}

variable "volume_gb" {
  type    = number
  default = 20
}

resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.key_name
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = var.public

  root_block_device {
    volume_size = var.volume_gb
    volume_type = "gp3"
    encrypted   = true
  }

  # IMDSv2 only: blocks the classic SSRF-to-credentials attack
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = var.name
    Role = var.role
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

output "id" {
  value = aws_instance.this.id
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "public_ip" {
  value = aws_instance.this.public_ip
}
