data "aws_eks_cluster" "main" {
  name = module.infrastructure.eks_cluster_name

  depends_on = [
    module.infrastructure
  ]
}

data "tls_certificate" "eks_oidc" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

locals {
  eks_oidc_issuer_url      = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
  eks_oidc_issuer_hostpath = replace(local.eks_oidc_issuer_url, "https://", "")

  aws_load_balancer_controller_sa_name = "aws-load-balancer-controller"
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = local.eks_oidc_issuer_url

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint
  ]

  tags = {
    Name = "${var.project_name}-eks-oidc"
  }
}

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"
      identifiers = [
        aws_iam_openid_connect_provider.eks.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_hostpath}:aud"
      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer_hostpath}:sub"
      values = [
        "system:serviceaccount:kube-system:${local.aws_load_balancer_controller_sa_name}"
      ]
    }
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.project_name}-aws-load-balancer-controller"
  description = "IAM policy for AWS Load Balancer Controller"

  policy = file("${path.module}/iam_policy.json")
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.project_name}-aws-load-balancer-controller"

  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json

  tags = {
    Name = "${var.project_name}-aws-load-balancer-controller"
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

resource "kubernetes_service_account_v1" "aws_load_balancer_controller" {
  metadata {
    name      = local.aws_load_balancer_controller_sa_name
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/name"       = "aws-load-balancer-controller"
      "app.kubernetes.io/managed-by" = "terraform"
    }

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  atomic  = true
  wait    = true
  timeout = 300

  set = [
    {
      name  = "clusterName"
      value = module.infrastructure.eks_cluster_name
    },
    {
      name  = "region"
      value = var.aws_region
    },
    {
      name  = "vpcId"
      value = module.infrastructure.vpc_id
    },
    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].name
    }
  ]

  depends_on = [
    kubernetes_service_account_v1.aws_load_balancer_controller
  ]
}
