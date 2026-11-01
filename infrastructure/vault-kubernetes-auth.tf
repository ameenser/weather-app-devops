resource "kubernetes_cluster_role_binding_v1" "vault_tokenreview" {
  metadata {
    name = "vault-tokenreview-binding"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "vault"
    namespace = kubernetes_namespace_v1.vault.metadata[0].name
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [
    helm_release.vault
  ]
}
