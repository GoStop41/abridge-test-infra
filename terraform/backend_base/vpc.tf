module "vpc" {
  source = "git@github.com:GoStop41/abridge-test-modules.git//m-vpc?ref=main"

  name = local.vpc_name

  nat_instances    = local.az_count
  az_width         = local.az_count
  cidr_block       = var.vpc_cidr
  enable_flow_logs = true

  newbits = {
    public   = "5"
    private  = "4"
    isolated = "5"
  }
  subnet_map = {
    public   = "3"
    private  = "3"
    isolated = "3"
  }
  netnum_shift_map = {
    public   = "0"
    private  = "6"
    isolated = "18"
  }

  tags = local.tags
  subnets_tags = {
    subnets_isolated = {
    }
    subnets_public = {
      "kubernetes.io/role/elb"          = "1"
    }
    subnets_private = {
      "karpenter.sh/discovery"          = local.name
      "kubernetes.io/role/internal-elb" = "1",
    }
  }
}