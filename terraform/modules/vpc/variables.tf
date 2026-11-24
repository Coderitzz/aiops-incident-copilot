variable "name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones (one public and one private subnet each)"
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Single NAT gateway so private hosts can reach the internet (costs money while it exists)"
  type        = bool
  default     = true
}
