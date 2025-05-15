terraform {
  backend "s3" {
    # Config defined in ../tfvars/backend_base/backend-dev.tfvars
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
    }
    sops = {
      source  = "carlpett/sops"
      version = "0.6.3"
    }
  }
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn     = var.assume_role_arn
    session_name = "terraform-environment-${var.environment}"
    external_id  = "terraform-environment-${var.environment}"
  }
}

# For resources dedicated in us-east-1 region, such as CloudFront and ACM.
provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
  assume_role {
    role_arn     = var.assume_role_arn
    session_name = "terraform-environment-${var.environment}"
    external_id  = "terraform-environment-${var.environment}"
  }
}
