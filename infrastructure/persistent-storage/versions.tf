terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Preserve the CSI ownership/discovery tags already present on volumes that
  # were originally provisioned by Kubernetes.
  ignore_tags {
    keys = [
      "CSIVolumeName",
      "KubernetesCluster",
    ]

    key_prefixes = [
      "ebs.csi.aws.com/",
      "kubernetes.io/",
    ]
  }
}
