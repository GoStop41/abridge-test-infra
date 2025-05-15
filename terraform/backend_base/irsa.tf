#module "example-svc" {
#  source               = "git@github.com/GoStop41/abridge-test-modules.git/m-irsa?ref=main"
#  service_account_name = "example-svc"
#  cluster_name         = module.eks.cluster_name
#  oidc_provider_arn    = module.eks.oidc_provider_arn
#  tags                 = local.tags
#  attach_role_policies = {
#    some_existing_policy = data.aws_iam_policy.some_existing_policy
#  }
#  role_policy = {
#    S3 = {
#      effect = "Allow"
#      resources = [
#        "arn:aws:s3:::${example_bucket}/*"
#      ]
#      actions = [
#        "s3:Get*",
#        "s3:List*",
#        "s3:Describe*"
#      ]
#    }
#  }
#}