resource "terraform_data" "sync_n8n_secret_from_vault" {
  depends_on = [
    terraform_data.vault_bootstrap
  ]

  triggers_replace = {
    script_hash        = filesha256("${path.module}/scripts/sync-n8n-secret-from-vault.sh")
    vault_bootstrap_id = terraform_data.vault_bootstrap.id
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/sync-n8n-secret-from-vault.sh"
  }
}
