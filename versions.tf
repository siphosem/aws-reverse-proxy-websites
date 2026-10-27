terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # Optional remote state. Create the bucket first, then uncomment.
  # backend "s3" {
  #   bucket       = "YOUR-tfstate-bucket"
  #   key          = "aws-reverse-proxy-websites/terraform.tfstate"
  #   region       = "eu-west-1"
  #   use_lockfile = true
  #   encrypt      = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}

data "aws_caller_identity" "current" {}

locals {
  name = "${var.company}-${var.environment}"

  # Tagging scheme from the project brief.
  tags = {
    Project     = var.company
    Environment = var.environment
    Automated   = "Yes"
    ManagedBy   = "terraform"
  }

  tooling_host = "tooling.${var.domain_name}"
}
