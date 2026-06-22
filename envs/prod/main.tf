terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment after running scripts/init-from-template.sh + bootstrap.
  # Get the values from `terraform -chdir=bootstrap output backend_config`.
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

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = {
    Project   = var.project_name
    Env       = var.environment_name
    Owner     = var.owner
    ManagedBy = "terraform"
  }
}
