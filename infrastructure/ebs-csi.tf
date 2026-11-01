locals {
  ebs_csi_controller_sa_name = "ebs-csi-controller-sa"
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
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
        "system:serviceaccount:kube-system:${local.ebs_csi_controller_sa_name}"
      ]
    }
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.project_name}-ebs-csi-driver"

  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json

  tags = {
    Name = "${var.project_name}-ebs-csi-driver"
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2"
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = module.infrastructure.eks_cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  depends_on = [
    aws_iam_role_policy_attachment.ebs_csi_driver
  ]

  tags = {
    Name = "${var.project_name}-ebs-csi-driver"
  }
}
