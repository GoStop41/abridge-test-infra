module "environment-key" {
  source = "git@github.com:GoStop41/abridge-test-modules.git//m-kms-key?ref=1.1"
  environment = var.environment
  tags        = local.tags
}