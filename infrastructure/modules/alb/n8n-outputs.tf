output "n8n_target_group_arn" {
  value = aws_lb_target_group.n8n.arn
}

output "n8n_target_group_name" {
  value = aws_lb_target_group.n8n.name
}
