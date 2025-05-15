locals {
  vpc_name               = "${var.product}-${var.environment}-vpc"
  azs                    = slice(data.aws_availability_zones.available.names, 0, 2)
  ips                    = yamldecode(file("../data/ips.yaml"))
  account_id             = data.aws_caller_identity.current.account_id
  az_count               = 3

  tags = {
    Product     = var.product
    Environment = var.environment
    Terraform   = true
  }
}
