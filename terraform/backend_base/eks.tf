locals {
  name            = "${var.product}-${var.environment}"
  cluster_version = "${var.eks_cluster_version}"
  ami_name        = "${var.eks_node_ami_name}"
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

#Finds the latest EKS worker AMI that matches a given name.
data "aws_ami" "eks_worker" {
  owners      = ["self", "amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = [local.ami_name]
  }
}

#### Role for eks csi driver
data "aws_kms_alias" "ebs" {
  name = "alias/aws/ebs"
}

data "aws_iam_policy" "aws_ebs_csid_driver" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_iam_role_policy" "ebs_csi_service_account_policy" {
  name   = "${module.eks.cluster_name}-csi-driver-policy"
  policy = data.aws_iam_policy_document.ebs_csi_policy.json
  role   = aws_iam_role.ebs_csi_driver_role.name
}

resource "aws_iam_role_policy_attachment" "ebc_csi_attach" {
  role       = aws_iam_role.ebs_csi_driver_role.name
  policy_arn = data.aws_iam_policy.aws_ebs_csid_driver.arn
}

data "aws_iam_policy_document" "ebs_csi_policy" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = [data.aws_kms_alias.ebs.target_key_arn]
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant"
    ]
  }
}

data "aws_iam_policy_document" "ebs_csi_trust_policy" {
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
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver_role" {
  name               = "${module.eks.cluster_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_trust_policy.json
  tags               = local.tags
}

####

provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region, "--role-arn", var.assume_role_arn]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region, "--role-arn", var.assume_role_arn]
    }
  }
  registry {
    url      = "oci://public.ecr.aws/karpenter"
    username = data.aws_ecrpublic_authorization_token.token.user_name
    password = data.aws_ecrpublic_authorization_token.token.password
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region, 
            "--role-arn", var.assume_role_arn]
  }
}

################################################################################
# EKS Module
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.2.0"

  cluster_name                         = local.name
  cluster_version                      = local.cluster_version
  #Allow access from public for now. We can secure it to be only accessible through a jump machine within the same vpc
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = concat(local.ips.vpn, local.ips.additional)

  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      most_recent                 = true
      service_account_role_arn    = aws_iam_role.ebs_csi_driver_role.arn
      resolve_conflicts_on_create = "OVERWRITE"
    }
    coredns = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      configuration_values = jsonencode({
        resources = {
          limits = {
            cpu = "0.5"
            memory = "512M"
          }
          requests = {
            cpu = "0.5"
            memory = "512M"
          }
        }
      })
    }
  }

  vpc_id                   = module.vpc.id
  subnet_ids               = module.vpc.subnets_private
  control_plane_subnet_ids = module.vpc.subnets_isolated

  # Fargate profiles use the cluster primary security group so these are not utilized
  create_cluster_security_group = false
  create_node_security_group    = false

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = var.instance_types
  }

  eks_managed_node_groups = {
    infra_worker = {
      ami_id = data.aws_ami.eks_worker.id
      enable_bootstrap_user_data = true
      desired_size = var.node_group_desired_size
      max_size = var.node_group_max_size
      min_size = var.node_group_min_size
      labels = {
        "nodegroup-name"="infra_worker"
      }
      # CriticalAddonsOnly=true:NoSchedule
      taints = [
        {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]

      metadata_options = {
        http_tokens                 = "optional"
      }
      #iam_role_additional_policies = {
      #Add as needed
      #}
      tags = {
        Name = "infra_worker/${module.eks.cluster_name}"
      }
    }
  }

  kms_key_administrators = [
    "${var.assume_role_arn}",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.devops_admin_role}"
  ]

  tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.name
  })
}

module "aws_auth_configmap" {
  source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
  version = "~> 20.0"

  manage_aws_auth_configmap = true
  aws_auth_roles = concat([
    for node_group in values(module.eks.eks_managed_node_groups) : {
      rolearn  = node_group.iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes"
      ]
    }],
    [{
      rolearn  = module.karpenter.node_iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
      },
      {
        rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.devops_admin_name}"
        username = "${var.devops_admin_name}"
        groups   = ["system:masters"]
      },
      {
        rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.assume_role_arn}"
        username = "${var.assume_role_arn}"
        groups   = ["system:masters"]
      },
  ])
}

################################################################################
# Karpenter
################################################################################


# eks-ENV-worker	Company managed	
# Allows EC2 instances to do generic AWS stuff
module "karpenter" {
  source                          = "terraform-aws-modules/eks/aws//modules/karpenter"
  version                         = "20.24.0"
  cluster_name                    = module.eks.cluster_name
  irsa_namespace_service_accounts = ["kube-system:karpenter"]
  irsa_oidc_provider_arn          = module.eks.oidc_provider_arn
  iam_role_use_name_prefix        = true
  enable_irsa                     = true

  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  #node_iam_role_additional_policies = {
  ########Add as needed
  #}

  tags = local.tags
}

resource "helm_release" "karpenter-crd" {
  namespace        = "kube-system"
  create_namespace = false
  name             = "karpenter-crd"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter-crd"
  version          = "1.0.8"
  timeout          = 600
  max_history      = 5
  values = []
  depends_on = [
    module.eks,
    module.karpenter
  ]
}

resource "helm_release" "karpenter" {
  namespace        = "kube-system"
  create_namespace = false
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.0.8"
  timeout          = 600
  max_history      = 5
  skip_crds        = true

  values = [<<-YAML
    settings:
        clusterName: ${module.eks.cluster_name}
        clusterEndpoint: ${module.eks.cluster_endpoint}
        interruptionQueue: ${module.karpenter.queue_name}
        featureGates:
          spotToSpotConsolidation: true
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
  YAML
  ]

  depends_on = [
    module.eks,
    module.karpenter,
    helm_release.karpenter-crd
  ]
}

resource "kubernetes_manifest" "karpenter_nodepool" {
  manifest = yamldecode(<<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: default
    spec:
      disruption:
        budgets:
        - nodes: 10%
        consolidateAfter: 15m
        consolidationPolicy: WhenEmptyOrUnderutilized
      limits:
        cpu: 1k
      template:
        metadata: {}
        spec:
          nodeClassRef:
            name: default
            group: karpenter.k8s.aws
            kind: EC2NodeClass
          requirements:
          - key: karpenter.sh/capacity-type
            operator: In
            values:
            - spot
          - key: capacity-spread
            operator: In
            values:
            - "2"
            - "3"
            - "4"
            - "5"
          - key: kubernetes.io/os
            operator: In
            values:
            - linux
          - key: kubernetes.io/arch
            operator: In
            values:
            - amd64
            #https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-target-groups.html#target-type
          - key: karpenter.k8s.aws/instance-family
            operator: NotIn
            values:
            - m1
            - m2
            - m3
            - t1
            - c1
            - cc1
            - cc2
            - cg1
            - cg2
          - key: karpenter.k8s.aws/instance-generation
            operator: Gt
            values:
            - "2"
          - key: "karpenter.k8s.aws/instance-cpu"
            operator: Gt
            values: 
            - "2"
          - key: "karpenter.k8s.aws/instance-memory"
            operator: Gt
            values:
            - "8000"
  YAML
  )
  depends_on = [
    helm_release.karpenter-crd
  ]
}


resource "kubernetes_manifest" "karpenter_ec2nodeclass" {
  manifest = yamldecode(<<-YAML
      apiVersion: karpenter.k8s.aws/v1
      kind: EC2NodeClass
      metadata:
        name: default
      spec:
        kubelet:
          systemReserved:
            cpu: 500m
            memory: 2000Mi
        amiFamily: AL2
        amiSelectorTerms:
        - id: ${data.aws_ami.eks_worker.id}
        metadataOptions:
          httpTokens: optional
        role: ${module.karpenter.node_iam_role_name}
        securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
        subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
        blockDeviceMappings:
        - deviceName: /dev/xvda
          rootVolume: true
          ebs:
            encrypted: true
            iops: ${var.eks_ebs_node_volume.iops}
            throughput: ${var.eks_ebs_node_volume.throughput}
            volumeSize: ${var.eks_ebs_node_volume.size}
            volumeType: ${var.eks_ebs_node_volume.type}
        tags:
          Name: karpenter.sh/${module.eks.cluster_name}
  YAML
  )
  depends_on = [
    helm_release.karpenter-crd
  ]
}

resource "kubectl_manifest" "storageclass_gp3_encrypted" {
  yaml_body = <<-YAML
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    allowVolumeExpansion: true
    metadata:
      annotations:
        storageclass.kubernetes.io/is-default-class: "true"
      name: gp3-encrypted
    parameters:
      encrypted: "true"
      csi.storage.k8s.io/fstype: ext4
      type: gp3
    provisioner: ebs.csi.aws.com
    reclaimPolicy: Delete
    volumeBindingMode: WaitForFirstConsumer
  YAML
}

output "eks" {
  value = {
    cluster_name                       = module.eks.cluster_name
    cluster_endpoint                   = module.eks.cluster_endpoint
    cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
    oidc_provider_arn                  = module.eks.oidc_provider_arn
    cluster_primary_security_group_id  = module.eks.cluster_primary_security_group_id
  }
}
