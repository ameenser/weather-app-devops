terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster_auth" "main" {
  name = module.infrastructure.eks_cluster_name
}

provider "kubernetes" {
  host                   = module.infrastructure.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.infrastructure.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.main.token
}


provider "helm" {
  kubernetes = {
    host                   = module.infrastructure.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.infrastructure.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}
