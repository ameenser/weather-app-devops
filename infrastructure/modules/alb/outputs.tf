output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_zone_id" {
  value = aws_lb.main.zone_id
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "jenkins_target_group_arn" {
  value = aws_lb_target_group.jenkins.arn
}

output "gitlab_target_group_arn" {
  value = aws_lb_target_group.gitlab.arn
}

output "eks_app_target_group_arn" {
  value = aws_lb_target_group.eks_app.arn
}

output "argocd_target_group_arn" {
  value = aws_lb_target_group.argocd.arn
}
