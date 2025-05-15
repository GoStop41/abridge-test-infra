locals {
  fluent_name          = "fluent-bit"
  log_group_name       = "${module.eks.cluster_name}-application-logs"
  fluent_bit_namespace = "amazon-cloudwatch"
  log_retention_days = 7
  region             = data.aws_region.current.name
  auto_create_group  = "On"
}

resource "aws_iam_role_policy" "service_account_policy" {
  name   = "${module.eks.cluster_name}-fluent-bit"
  policy = data.aws_iam_policy_document.fluent-bit.json
  role   = aws_iam_role.fluent_bit.name
}

data "aws_iam_policy_document" "fluent-bit" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "cloudwatch:PutMetricData",
      "ec2:DescribeVolumes",
      "ec2:DescribeTags",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
    ]
  }
}

data "aws_iam_policy_document" "trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider_arn, "/arn:aws:iam::[0-9]{12}:oidc-provider\\//", "")}:sub"
      values   = ["system:serviceaccount:${local.fluent_bit_namespace}:fluent-bit"]
    }
  }
}

resource "aws_iam_role" "fluent_bit" {
  name               = "${module.eks.cluster_name}-fluent-bit"
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
  tags               = local.tags
}

resource "helm_release" "fluent-bit" {
  name             = local.fluent_name
  repository       = "https://fluent.github.io/helm-charts"
  chart            = "fluent-bit"
  version          = "0.44.0"
  namespace        = "amazon-cloudwatch"
  create_namespace = true
  max_history      = 5
  values = [
    templatefile(
      "fluent-bit-values.yaml",
      {
        region                = local.region
        cluster_name          = "${module.eks.cluster_name}"
        log_group_name        = local.log_group_name
        log_retention_days    = local.log_retention_days
        auto_create_group     = local.auto_create_group
      }
    )
  ]

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.name"
    value = "fluent-bit"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_iam_role.fluent_bit.name}"
  }
  depends_on = [
    aws_iam_role.fluent_bit
  ]
}
