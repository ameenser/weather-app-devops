variable "project_name" {
  type        = string
  description = "Project name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for the ALB"
}

variable "jenkins_instance_id" {
  type        = string
  description = "Jenkins Controller EC2 instance ID"
}

variable "gitlab_instance_id" {
  type        = string
  description = "GitLab EC2 instance ID"
}

variable "eks_cluster_security_group_id" {
  type        = string
  description = "EKS cluster security group ID used by worker nodes"
}

variable "eks_node_group_asg_map" {
  type        = map(string)
  description = "Auto Scaling Group names behind the EKS managed node group"
}

variable "jenkins_domain" {
  type        = string
  description = "Jenkins domain"
}

variable "gitlab_domain" {
  type        = string
  description = "GitLab domain"
}

variable "app_domain" {
  type        = string
  description = "Application domain"
}

variable "app_node_port" {
  type        = number
  description = "NodePort exposed by Kubernetes Service"
}

variable "gitlab_sg_v2_id" {
  description = "New GitLab security group ID for blue/green SG migration"
  type        = string
  default     = null
}

variable "jenkins_sg_v2_id" {
  description = "New Jenkins controller security group ID for blue/green SG migration"
  type        = string
}

variable "app_prod_node_port" {
  type        = number
  description = "NodePort for production weather app"
}

variable "app_staging_node_port" {
  type        = number
  description = "NodePort for staging weather app"
}

variable "app_staging_domain" {
  type        = string
  description = "Staging application domain"
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN used by the public ALB HTTPS listener"
}

variable "argocd_domain" {
  type        = string
  description = "Public domain used for Argo CD"
}
