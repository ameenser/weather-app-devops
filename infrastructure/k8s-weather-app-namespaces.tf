locals {
  weather_app_namespaces = toset([
    "wa-staging",
    "wa-prod",
  ])
}

resource "kubernetes_namespace_v1" "weather_app_envs" {
  for_each = local.weather_app_namespaces

  metadata {
    name = each.key

    labels = {
      "app.kubernetes.io/name"       = "weather-app"
      "app.kubernetes.io/managed-by" = "terraform"
      environment                    = replace(each.key, "wa-", "")
    }
  }
}

resource "kubernetes_role_binding_v1" "jenkins_weather_app_env_deployer_binding" {
  for_each = kubernetes_namespace_v1.weather_app_envs

  metadata {
    name      = "jenkins-weather-app-deployer-binding"
    namespace = each.value.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.jenkins.metadata[0].name
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }

  role_ref {
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.jenkins_deployer.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
}
