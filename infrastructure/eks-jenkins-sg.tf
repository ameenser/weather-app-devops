resource "aws_vpc_security_group_ingress_rule" "eks_api_from_jenkins" {
  security_group_id            = module.infrastructure.eks_cluster_security_group_id
  referenced_security_group_id = module.infrastructure.jenkins_controller_security_group_id

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443

  description = "Allow Jenkins controller to access EKS API"
}
