output "volume_ids" {
  description = "Persistent EBS volume IDs keyed by workload."
  value       = { for name, volume in aws_ebs_volume.persistent : name => volume.id }
}

output "n8n_volume_id" {
  description = "New n8n EBS volume ID to place in the n8n static PersistentVolume manifest after the first apply."
  value       = aws_ebs_volume.persistent["n8n"].id
}

output "backup_vault_name" {
  description = "AWS Backup vault used for persistent volumes, or null when backups are disabled."
  value       = try(aws_backup_vault.persistent_storage[0].name, null)
}
