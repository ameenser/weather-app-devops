resource "terraform_data" "vault_bootstrap" {
  depends_on = [
    helm_release.vault,
    kubernetes_cluster_role_binding_v1.vault_tokenreview
  ]

  triggers_replace = {
    script_hash = filesha256("${path.module}/scripts/bootstrap-vault-weather-app.sh")
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/bootstrap-vault-weather-app.sh"
  }
}
