region         = "us-west-1"
bucket         = "ab-infra-dev-terraform-state"
key            = "ab-infra-dev/backend_base/terraform.tfstate"
dynamodb_table = "ab-infra-dev-terraform-state"
role_arn       = "arn:aws:iam::your_account_number:role/CICD-DevOps"
