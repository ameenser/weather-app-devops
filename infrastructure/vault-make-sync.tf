resource "terraform_data" "sync_make_webhook_from_vault" {
  depends_on = [
    helm_release.vault,
    kubernetes_cluster_role_binding_v1.vault_tokenreview,
    terraform_data.vault_bootstrap
  ]

  triggers_replace = {
    script_hash        = filesha256("${path.module}/scripts/sync-make-webhook-from-vault.sh")
    vault_bootstrap_id = terraform_data.vault_bootstrap.id
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/sync-make-webhook-from-vault.sh"
  }
}
