variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "project" {
  type    = string
  default = "aiops"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "admin_cidr" {
  description = "Your public IP as a /32, e.g. 203.0.113.10/32"
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0))
    error_message = "admin_cidr must be a valid CIDR such as 203.0.113.10/32."
  }

  validation {
    condition     = var.admin_cidr != "0.0.0.0/0"
    error_message = "Do not open SSH to the whole internet. Use your own IP /32."
  }
}

variable "public_key_path" {
  description = "Path to the SSH public key to install on the hosts"
  type        = string
  default     = "~/.ssh/aiops.pub"
}

variable "enable_nat_gateway" {
  description = "NAT gives private hosts internet access (needed by Ansible and k3s). Biggest fixed cost."
  type        = bool
  default     = true
}

variable "instances" {
  description = "Hosts to create. The map key becomes the Role tag."
  type = map(object({
    instance_type = string
    public        = bool
    volume_gb     = number
  }))
  default = {
    bastion = { instance_type = "t3.micro", public = true, volume_gb = 10 }
    ci      = { instance_type = "c7i-flex.large", public = false, volume_gb = 30 }
    k3s     = { instance_type = "c7i-flex.large", public = false, volume_gb = 40 }
  }

  validation {
    condition     = contains(keys(var.instances), "bastion")
    error_message = "The instances map must contain a 'bastion' entry."
  }
}

variable "ecr_repositories" {
  type    = list(string)
  default = ["frontend", "order-service", "payment-service", "inventory-service", "ai-agent"]
}
