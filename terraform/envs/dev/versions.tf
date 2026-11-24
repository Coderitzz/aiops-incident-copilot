terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.80" }
  }

  # Values are injected by `make tf-init` (partial backend configuration)
  backend "s3" {}
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
