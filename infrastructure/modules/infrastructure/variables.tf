variable "vpc_cidr" {
  type = string
}

variable "public_subnet_1_cidr" {
  type = string
}

variable "public_subnet_2_cidr" {
  type = string
}

variable "private_subnet_1_cidr" {
  type = string
}

variable "private_subnet_2_cidr" {
  type = string
}

variable "availability_zone_1" {
  type = string
}

variable "availability_zone_2" {
  type = string
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
  type = string
}

variable "jenkins_controller_instance_type" {
  type = string
}

variable "jenkins_agent_instance_type" {
  type = string
}

variable "internal_domain" {
  type = string
}
variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster name"
}

variable "eks_cluster_version" {
  type        = string
  description = "EKS Kubernetes version. Null means AWS default."
  default     = null
}

variable "eks_node_group_name" {
  type        = string
  description = "EKS managed node group name"
  default     = "main"
}

variable "eks_node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for EKS worker nodes"
  default     = ["t3.medium"]
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
  description = "Project name used for resource names and tags"
}


variable "jenkins_home_volume_id" {
  description = "Existing persistent Jenkins home EBS volume"
  type        = string
}

variable "gitlab_data_volume_id" {
  description = "Existing persistent GitLab data EBS volume"
  type        = string
}
