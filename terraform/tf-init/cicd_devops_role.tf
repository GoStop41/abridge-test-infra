data "aws_caller_identity" "main" {}

resource "aws_iam_role" "cicd_devops_role" {
  name               = var.cicd_devops_role_name
  tags               = merge(var.tags, { "HumanUse" = "false" })
  assume_role_policy = data.aws_iam_policy_document.cicd_devops_assume_role.json
}

data "aws_iam_policy_document" "cicd_devops_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    principals {
      identifiers = concat(
        [
          "arn:aws:iam::${data.aws_caller_identity.main.account_id}:role/${var.terraform_parent_role}"
      ], var.additional_admin_roles)
      type = "AWS"
    }
  }
}

resource "aws_iam_role_policy" "cicd_devops_policy" {
  name   = "cicd_devops_policy"
  role   = aws_iam_role.cicd_devops_role.id
  policy = data.aws_iam_policy_document.cicd_devops_policy.json
}

########We can restrict the access as needed. 
data "aws_iam_policy_document" "cicd_devops_policy" {
  statement {
    actions   = ["*"]
    resources = ["*"]
  }
}

output "cicd_devops_role_arn" {
    value = aws_iam_role.cicd_devops_role.arn
}
