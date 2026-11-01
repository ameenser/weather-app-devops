output "vpc_id" {
  value = module.infrastructure.vpc_id
}

output "public_subnet_ids" {
  value = module.infrastructure.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.infrastructure.private_subnet_ids
}

output "gitlab_private_ip" {
  value = module.infrastructure.gitlab_private_ip
}

output "jenkins_agent_private_ip" {
  value = module.infrastructure.jenkins_agent_private_ip
}

output "gitlab_instance_id" {
  value = module.infrastructure.gitlab_instance_id
}

output "jenkins_agent_instance_id" {
  value = module.infrastructure.jenkins_agent_instance_id
}

output "jenkins_controller_instance_id" {
  value = module.infrastructure.jenkins_controller_instance_id
}

output "jenkins_controller_private_ip" {
  value = module.infrastructure.jenkins_controller_private_ip
}

output "gitlab_data_volume_id" {
  value = module.infrastructure.gitlab_data_volume_id
}

output "jenkins_home_volume_id" {
  value = module.infrastructure.jenkins_home_volume_id
}

output "eks_cluster_name" {
  value = module.infrastructure.eks_cluster_name
}

output "eks_cluster_endpoint" {
  value = module.infrastructure.eks_cluster_endpoint
}

output "eks_node_group_name" {
  value = module.infrastructure.eks_node_group_name
}

output "eks_node_group_asg_names" {
  value = module.infrastructure.eks_node_group_asg_names
}

output "eks_cluster_security_group_id" {
  value = module.infrastructure.eks_cluster_security_group_id
}

output "eks_node_group_asg_map" {
  value = module.infrastructure.eks_node_group_asg_map
}
output "eks_cluster_certificate_authority_data" {
  value     = module.infrastructure.eks_cluster_certificate_authority_data
  sensitive = true
}


output "argocd_ui_url" {
  description = "Argo CD Web UI URL"
  value       = "https://${var.argocd_domain}"
}

output "argocd_cli_login_command" {
  description = "Command for connecting the Argo CD CLI through the ALB"
  value       = "argocd login ${var.argocd_domain} --username admin --grpc-web"
}

output "argocd_initial_admin_password_command" {
  description = "Command that retrieves the initial Argo CD admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
}
