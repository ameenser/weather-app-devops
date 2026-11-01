output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
}

output "private_subnet_ids" {
  value = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]
}

output "public_subnet_1_id" {
  value = aws_subnet.public_1.id
}

output "public_subnet_2_id" {
  value = aws_subnet.public_2.id
}

output "private_subnet_1_id" {
  value = aws_subnet.private_1.id
}

output "private_subnet_2_id" {
  value = aws_subnet.private_2.id
}

output "gitlab_instance_id" {
  value = aws_instance.gitlab.id
}

output "gitlab_private_ip" {
  value = aws_instance.gitlab.private_ip
}

output "jenkins_agent_instance_id" {
  value = aws_instance.jenkins_agent.id
}

output "jenkins_agent_private_ip" {
  value = aws_instance.jenkins_agent.private_ip
}

output "jenkins_agent_security_group_id" {
  value = aws_security_group.jenkins_agent.id
}

output "jenkins_controller_instance_id" {
  value = aws_instance.jenkins_controller.id
}

output "jenkins_controller_private_ip" {
  value = aws_instance.jenkins_controller.private_ip
}

output "jenkins_controller_security_group_id" {
  value = module.jenkins_controller_sg_new.id
}

output "gitlab_data_volume_id" {
  value = local.gitlab_data_volume_id
}

output "jenkins_home_volume_id" {
  value = local.jenkins_home_volume_id
}

output "private_zone_id" {
  value = aws_route53_zone.private.zone_id
}

output "gitlab_dns_name" {
  value = aws_route53_record.gitlab.fqdn
}

output "jenkins_controller_dns_name" {
  value = aws_route53_record.jenkins_controller.fqdn
}

output "jenkins_agent_dns_name" {
  value = aws_route53_record.jenkins_agent.fqdn
}


output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "eks_cluster_certificate_authority_data" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}

output "eks_cluster_security_group_id" {
  value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "eks_node_group_name" {
  value = aws_eks_node_group.main.node_group_name
}

output "eks_node_group_asg_names" {
  value = flatten([
    for resource in aws_eks_node_group.main.resources : [
      for asg in resource.autoscaling_groups : asg.name
    ]
  ])
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node_role.arn
}

output "eks_node_group_asg_map" {
  description = "Static-key map of EKS node group ASG names for ALB attachment"

  value = {
    app = aws_eks_node_group.main.resources[0].autoscaling_groups[0].name
  }
}

output "gitlab_security_group_v2_id" {
  value = module.gitlab_sg_new.id
}

output "jenkins_controller_security_group_v2_id" {
  value = module.jenkins_controller_sg_new.id
}
