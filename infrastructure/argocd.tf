locals {
  argocd_namespace = "argocd"
  argocd_release   = "argocd"
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = local.argocd_namespace

    labels = {
      "app.kubernetes.io/name"       = "argocd"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "argocd" {
  name       = local.argocd_release
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  create_namespace = false

  # Migration only:
  # Adopt the existing resources that were created using kubectl manifests.
  take_ownership = true

  # Keep these false during the first adoption.
  # We do not want a failed Helm installation to clean up adopted resources.
  atomic          = false
  cleanup_on_fail = false

  wait    = true
  timeout = 900

  values = [
    yamlencode({
      global = {
        domain = var.argocd_domain
      }

      configs = {
        cm = {
          url = "https://${var.argocd_domain}"

          # Local UI account for a teammate.
          "accounts.teammate-readonly" = "login"
        }

        rbac = {
          # Do not grant permissions to every authenticated user by default.
          "policy.default" = ""

          # Assign only this local account to Argo CD's built-in read-only role.
          "policy.csv" = <<-EOT
	      g, teammate-readonly, role:readonly
	    EOT
        }

        params = {
          # Public traffic remains HTTPS.
          # TLS terminates at the AWS ALB.
          "server.insecure" = "true"
        }
      }

      server = {
        ingress = {
          enabled = false
        }

        service = {
          type = "ClusterIP"
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.argocd
  ]
}

resource "kubernetes_manifest" "argocd_target_group_binding" {
  manifest = {
    apiVersion = "elbv2.k8s.aws/v1beta1"
    kind       = "TargetGroupBinding"

    metadata = {
      name      = "argocd-server-main-alb"
      namespace = kubernetes_namespace_v1.argocd.metadata[0].name

      labels = {
        "app.kubernetes.io/name"       = "argocd-server"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }

    spec = {
      serviceRef = {
        name = "argocd-server"
        port = 80
      }

      targetGroupARN = module.alb.argocd_target_group_arn
      targetType     = "ip"
    }
  }

  depends_on = [
    helm_release.argocd,
    helm_release.aws_load_balancer_controller
  ]
}




resource "aws_route53_record" "argocd" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.argocd_domain
  type    = "A"

  allow_overwrite = true

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

resource "kubernetes_secret_v1" "argocd_gitops_repository" {
  metadata {
    name      = "weather-app-gitops-repo"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name

    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
      "app.kubernetes.io/managed-by"   = "terraform"
    }
  }

  type = "Opaque"

  data = {
    type     = "git"
    url      = var.argocd_gitops_repo_url
    username = var.argocd_git_username
    password = var.argocd_git_password
    project  = "default"
  }

  depends_on = [
    helm_release.argocd
  ]
}

resource "helm_release" "argocd_bootstrap" {
  name      = "argocd-bootstrap"
  chart     = "${path.module}/charts/argocd-bootstrap"
  namespace = kubernetes_namespace_v1.argocd.metadata[0].name

  atomic          = true
  cleanup_on_fail = true
  wait            = true
  timeout         = 300

  values = [
    yamlencode({
      repoURL          = var.argocd_gitops_repo_url
      targetRevision   = "main"
      applicationsPath = "argocd/applications"
    })
  ]

  depends_on = [
    helm_release.argocd,
    kubernetes_secret_v1.argocd_gitops_repository,
    terraform_data.sync_make_webhook_from_vault

  ]
}
