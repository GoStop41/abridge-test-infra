product                = "test"
environment            = "dev"  #could be qa, staging ... etc.
region                 = "us-west-1"
account_id             = "your_account_number"
assume_role_arn        = "arn:aws:iam::your_account_number:role/CICD-DevOps"
devops_admin_role      = "your_role"
#This is the username put into aws-auth-config
devops_admin_name      = "your_username"


eks_ebs_node_volume = {
  size = "100Gi"
}
