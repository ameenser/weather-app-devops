data "aws_iam_policy_document" "backup_assume_role" {
  count = var.enable_backups ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  count = var.enable_backups ? 1 : 0

  name               = "${var.project_name}-persistent-storage-backup"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role[0].json

  tags = {
    ManagedBy = "terraform-persistent-storage"
  }
}

resource "aws_iam_role_policy_attachment" "backup" {
  count = var.enable_backups ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_vault" "persistent_storage" {
  count = var.enable_backups ? 1 : 0

  name = "${var.project_name}-persistent-storage"

  tags = {
    ManagedBy = "terraform-persistent-storage"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_backup_plan" "persistent_storage" {
  count = var.enable_backups ? 1 : 0

  name = "${var.project_name}-persistent-storage-daily"

  rule {
    rule_name                    = "daily-ebs-backup"
    target_vault_name            = aws_backup_vault.persistent_storage[0].name
    schedule                     = "cron(0 2 * * ? *)"
    schedule_expression_timezone = "Asia/Jerusalem"
    start_window                 = 60
    completion_window            = 180

    lifecycle {
      delete_after = var.backup_retention_days
    }

    recovery_point_tags = {
      ManagedBy = "terraform-persistent-storage"
    }
  }

  tags = {
    ManagedBy = "terraform-persistent-storage"
  }
}

resource "aws_backup_selection" "persistent_storage" {
  count = var.enable_backups ? 1 : 0

  name         = "${var.project_name}-persistent-ebs-volumes"
  plan_id      = aws_backup_plan.persistent_storage[0].id
  iam_role_arn = aws_iam_role.backup[0].arn
  resources    = [for volume in aws_ebs_volume.persistent : volume.arn]

  depends_on = [aws_iam_role_policy_attachment.backup]
}

resource "aws_rbin_rule" "persistent_volumes" {
  count = var.enable_recycle_bin ? 1 : 0

  description   = "Recover accidentally deleted persistent project EBS volumes"
  resource_type = "EBS_VOLUME"

  retention_period {
    retention_period_unit  = "DAYS"
    retention_period_value = var.recycle_bin_retention_days
  }

  resource_tags {
    resource_tag_key   = "Persistence"
    resource_tag_value = "retain"
  }

  tags = {
    ManagedBy = "terraform-persistent-storage"
  }
}
