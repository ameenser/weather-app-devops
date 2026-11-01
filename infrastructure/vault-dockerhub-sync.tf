resource "terraform_data" "sync_dockerhub_secret_from_vault" {
  depends_on = [
    helm_release.vault,
    kubernetes_cluster_role_binding_v1.vault_tokenreview,
    kubernetes_namespace_v1.weather_app,
    kubernetes_namespace_v1.weather_app_envs,
    terraform_data.vault_bootstrap
  ]

  triggers_replace = {
    script_hash = filesha256("${path.module}/scripts/sync-dockerhub-secret-from-vault.sh")
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/sync-dockerhub-secret-from-vault.sh"
  }
}
