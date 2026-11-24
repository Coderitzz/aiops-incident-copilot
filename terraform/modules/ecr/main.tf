variable "name_prefix" {
  type = string
}

variable "repositories" {
  type = list(string)
}

variable "keep_last" {
  type    = number
  default = 10
}

resource "aws_ecr_repository" "this" {
  for_each     = toset(var.repositories)
  name         = "${var.name_prefix}/${each.key}"
  force_delete = true # lets terraform destroy remove repos that still hold images

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last ${var.keep_last} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_last
      }
      action = { type = "expire" }
    }]
  })
}

output "repository_urls" {
  value = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}
