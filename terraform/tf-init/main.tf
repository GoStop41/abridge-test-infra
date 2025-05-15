module "state" {
  source = "git@github.com:GoStop41/abridge-test-modules.git//m-tfstate?ref=main"

  name                   = var.name
  terraform_parent_role  = var.terraform_parent_role
  region                 = var.region
}

output "state_s3_bucket" {
  value = module.state.state_s3_bucket.arn
}

output "state_dynamodb_table" {
  value = module.state.state_dynamodb_table.arn
}
