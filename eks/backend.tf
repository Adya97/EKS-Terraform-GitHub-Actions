terraform {
  required_version = "~> 1.13.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.49.0"
    }
  }

  backend "s3" {
    bucket       = "dev-adya-tf-bucket"
    region       = "eu-central-1"
    key          = "eks/terraform.tfstate"
    encrypt      = true
    use_lockfile = true   # replaces deprecated `dynamodb_table`
    # If you previously used workspaces with a prefix, uncomment:
    # workspaces { prefix = "env" }
  }
}

# NOTE: variable names can't contain hyphens. Use `aws_region`.
provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for provider"
  type        = string
  default     = "eu-central-1"
}
