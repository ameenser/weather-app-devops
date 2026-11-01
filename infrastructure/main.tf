module "infrastructure" {
  source = "./modules/infrastructure"

  vpc_cidr              = var.vpc_cidr
  public_subnet_1_cidr  = var.public_subnet_1_cidr
  public_subnet_2_cidr  = var.public_subnet_2_cidr
  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
  availability_zone_1   = var.availability_zone_1
  availability_zone_2   = var.availability_zone_2

  key_name                  = var.key_name
  my_ip                     = var.my_ip
  gitlab_ami_id             = var.gitlab_ami_id
  jenkins_agent_ami_id      = var.jenkins_agent_ami_id
  gitlab_data_volume_id     = var.gitlab_data_volume_id
  jenkins_controller_ami_id = var.jenkins_controller_ami_id


  gitlab_instance_type             = var.gitlab_instance_type
  jenkins_controller_instance_type = var.jenkins_controller_instance_type
  jenkins_agent_instance_type      = var.jenkins_agent_instance_type
  jenkins_home_volume_id           = var.jenkins_home_volume_id
  internal_domain                  = var.internal_domain

  project_name = var.project_name

  eks_cluster_name        = var.eks_cluster_name
  eks_cluster_version     = var.eks_cluster_version
  eks_node_group_name     = var.eks_node_group_name
  eks_node_instance_types = var.eks_node_instance_types
  eks_node_desired_size   = var.eks_node_desired_size
  eks_node_min_size       = var.eks_node_min_size
  eks_node_max_size       = var.eks_node_max_size

}


module "alb" {
  source = "./modules/alb"

  project_name = var.project_name

  vpc_id            = module.infrastructure.vpc_id
  public_subnet_ids = module.infrastructure.public_subnet_ids

  jenkins_instance_id = module.infrastructure.jenkins_controller_instance_id
  jenkins_sg_v2_id    = module.infrastructure.jenkins_controller_security_group_v2_id

  gitlab_instance_id = module.infrastructure.gitlab_instance_id
  gitlab_sg_v2_id    = module.infrastructure.gitlab_security_group_v2_id

  acm_certificate_arn = var.argocd_acm_certificate_arn

  eks_cluster_security_group_id = module.infrastructure.eks_cluster_security_group_id
  eks_node_group_asg_map        = module.infrastructure.eks_node_group_asg_map

  jenkins_domain = var.jenkins_domain
  gitlab_domain  = var.gitlab_domain
  app_domain     = var.app_domain
  argocd_domain  = var.argocd_domain
  n8n_domain     = var.n8n_domain
  n8n_ui_domain  = var.n8n_ui_domain


  app_node_port         = var.app_node_port
  app_prod_node_port    = var.app_prod_node_port
  app_staging_node_port = var.app_staging_node_port
  app_staging_domain    = var.app_staging_domain

}
