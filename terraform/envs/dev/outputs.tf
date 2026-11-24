output "bastion_public_ip" {
  value = module.hosts["bastion"].public_ip
}

output "private_ips" {
  value = { for k, h in module.hosts : k => h.private_ip if k != "bastion" }
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
