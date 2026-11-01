resource "kubernetes_namespace_v1" "vault" {
  metadata {
    name = "vault"

    labels = {
      "app.kubernetes.io/name"       = "vault"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.34.0"
  namespace  = kubernetes_namespace_v1.vault.metadata[0].name

  values = [
    file("${path.module}/helm-values/vault/vault-values.yaml")
  ]

  atomic  = false
  wait    = false
  timeout = 600

  depends_on = [
    kubernetes_namespace_v1.vault,
    aws_eks_addon.ebs_csi_driver,
    kubernetes_manifest.vault_data_persistent_volume
  ]
}
