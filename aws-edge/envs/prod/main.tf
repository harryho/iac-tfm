terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # After running bootstrap (`cd bootstrap && terraform apply`), uncomment
  # this block and fill in the values from
  # `terraform -chdir=bootstrap output backend_config`. `init-from-template.sh`
  # does not touch this file — you must do it by hand.
  #
  # backend "s3" {
  #   bucket         = "iac-tfm-state-<account>-<region>"
  #   key            = "envs/prod/terraform.tfstate"
  #   region         = "ap-southeast-2"
  #   dynamodb_table = "iac-tfm-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

locals {
  common_tags = {
    Project   = var.project_name
    Env       = var.environment_name
    Owner     = var.owner
    ManagedBy = "terraform"
  }
}
