resource "kubernetes_namespace_v1" "jenkins" {
  metadata {
    name = "jenkins"

    labels = {
      name = "jenkins"
    }
  }
}

resource "kubernetes_namespace_v1" "weather_app" {
  metadata {
    name = "weather-app"
  }
}

resource "kubernetes_service_account_v1" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }
}

resource "kubernetes_cluster_role_v1" "jenkins_deployer" {
  metadata {
    name = "jenkins-deployer"
  }

  # Permissions for Jenkins Kubernetes dynamic agents
  rule {
    api_groups = [""]
    resources = [
      "pods",
      "pods/exec",
      "pods/log",
      "events",
      "persistentvolumeclaims"
    ]
    verbs = [
      "get",
      "list",
      "watch",
      "create",
      "delete",
      "patch",
      "update"
    ]
  }

  # Read-only access for basic Jenkins/K8s config objects
  rule {
    api_groups = [""]
    resources = [
      "secrets",
      "configmaps",
      "services"
    ]
    verbs = [
      "get",
      "list",
      "watch",
      "create",
      "delete",
      "patch",
      "update"
    ]
  }

  # Permissions for Jenkins to deploy/update the weather-app Deployment
  rule {
    api_groups = ["apps"]
    resources = [
      "deployments",
      "replicasets"
    ]
    verbs = [
      "get",
      "list",
      "watch",
      "create",
      "delete",
      "patch",
      "update"
    ]
  }
}

resource "kubernetes_role_binding_v1" "jenkins_agent_rolebinding" {
  metadata {
    name      = "jenkins-agent-rolebinding"
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
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

resource "kubernetes_role_binding_v1" "jenkins_weather_app_deployer_binding" {
  metadata {
    name      = "jenkins-weather-app-deployer-binding"
    namespace = kubernetes_namespace_v1.weather_app.metadata[0].name
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

resource "kubernetes_secret_v1" "jenkins_token" {
  metadata {
    name      = "jenkins-token"
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name

    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.jenkins.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true

  depends_on = [
    kubernetes_service_account_v1.jenkins
  ]
}
