variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "private_subnet_1_cidr" {
  type    = string
  default = "10.0.11.0/24"
}

variable "private_subnet_2_cidr" {
  type    = string
  default = "10.0.12.0/24"
}

variable "availability_zone_1" {
  type    = string
  default = "us-east-1a"
}

variable "availability_zone_2" {
  type    = string
  default = "us-east-1b"
}

variable "key_name" {
  type = string
}

variable "my_ip" {
  type = string
}

variable "gitlab_ami_id" {
  type = string
}

variable "jenkins_agent_ami_id" {
  type = string
}

variable "jenkins_controller_ami_id" {
  type = string
}

variable "gitlab_instance_type" {
  type    = string
  default = "t3.large"
}

variable "jenkins_controller_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "jenkins_agent_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "internal_domain" {
  type    = string
  default = "golden-ami.internal"
}

variable "eks_cluster_name" {
  type    = string
  default = "weather-app-q3-eks"
}

variable "eks_cluster_version" {
  type    = string
  default = null
}

variable "eks_node_group_name" {
  type    = string
  default = "weather-app-workers"
}

variable "eks_node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "eks_node_desired_size" {
  type    = number
  default = 2
}

variable "eks_node_min_size" {
  type    = number
  default = 1
}

variable "eks_node_max_size" {
  type    = number
  default = 3
}
variable "project_name" {
  type        = string
  description = "Project name used for naming resources"
}


variable "app_node_port" {
  type        = number
  description = "Fixed NodePort for ALB target group"
}

variable "jenkins_domain" {
  type    = string
  default = "jenkins.weather-app-as.com"
}

variable "gitlab_domain" {
  type    = string
  default = "gitlab.weather-app-as.com"
}

variable "app_domain" {
  type    = string
  default = "app.weather-app-as.com"
}
variable "app_prod_node_port" {
  type        = number
  description = "NodePort for production weather app"
  default     = 30082
}

variable "app_staging_node_port" {
  type        = number
  description = "NodePort for staging weather app"
  default     = 30081
}

variable "app_staging_domain" {
  type        = string
  description = "Staging application domain"
  default     = "staging.weather-app-as.com"
}

variable "domain_name" {
  type        = string
  description = "Public Route53 domain name"
  default     = "weather-app-as.com"
}
variable "jenkins_url" {
  type        = string
  description = "Jenkins URL"
  default     = "http://jenkins.weather-app-as.com"
}



variable "jenkins_internal_url" {
  description = "Jenkins URL that Kubernetes dynamic agents use to connect back to Jenkins controller"
  type        = string
}

variable "jenkins_home_volume_id" {
  description = "Existing persistent Jenkins home EBS volume"
  type        = string
}

variable "gitlab_data_volume_id" {
  description = "Existing persistent GitLab data EBS volume"
  type        = string
}


variable "argocd_domain" {
  description = "Public DNS name for the Argo CD UI and API"
  type        = string
  default     = "argocd.weather-app-as.com"
}

variable "argocd_chart_version" {
  description = "Pinned Argo CD Helm chart version"
  type        = string
  default     = "10.1.3"
}

variable "argocd_acm_certificate_arn" {
  description = "ACM certificate ARN used by the Argo CD ALB listener"
  type        = string
}

variable "argocd_gitops_repo_url" {
  description = "GitOps repository used by Argo CD"
  type        = string
  default     = "http://gitlab.weather-app-as.com/ameenser/weather-app-gitops.git"
}

variable "argocd_git_username" {
  description = "Username used by Argo CD to read the GitOps repository"
  type        = string
  sensitive   = true
}

variable "argocd_git_password" {
  description = "Password or token used by Argo CD to read the GitOps repository"
  type        = string
  sensitive   = true
}
