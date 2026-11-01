resource "terraform_data" "configure_jenkins_k8s" {
  depends_on = [
    kubernetes_namespace_v1.jenkins,
    kubernetes_namespace_v1.weather_app,

    kubernetes_service_account_v1.jenkins,

    kubernetes_cluster_role_v1.jenkins_deployer,

    kubernetes_role_binding_v1.jenkins_agent_rolebinding,
    kubernetes_role_binding_v1.jenkins_weather_app_deployer_binding,

    kubernetes_secret_v1.jenkins_token,

    aws_vpc_security_group_ingress_rule.eks_api_from_jenkins,
    terraform_data.vault_bootstrap
  ]

  triggers_replace = {
    eks_endpoint_sha = module.infrastructure.eks_cluster_endpoint

    configure_script_sha       = filesha256("${path.module}/scripts/configure-jenkins-k8s-safe.sh")
    configure_vault_script_sha = filesha256("${path.module}/scripts/configure-jenkins-k8s-from-vault.sh")
    agent_yaml_sha             = filesha256("${path.module}/jenkins-agents/weather-ci-agent.yaml")

  }

  provisioner "local-exec" {
    command     = "${path.module}/scripts/configure-jenkins-k8s-from-vault.sh"
    interpreter = ["/usr/bin/env", "bash", "-c"]

    environment = {
      JENKINS_URL = var.jenkins_url

      K8S_NAMESPACE   = "jenkins"
      K8S_SECRET_NAME = "jenkins-token"

      K8S_API_URL = module.infrastructure.eks_cluster_endpoint

      JENKINS_INTERNAL_URL = var.jenkins_internal_url
    }
  }
}
