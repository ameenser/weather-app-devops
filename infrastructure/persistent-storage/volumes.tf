locals {
  volumes = {
    gitlab_data = {
      availability_zone = "us-east-1a"
      size              = 60
      component         = "gitlab"
    }
    jenkins_home = {
      availability_zone = "us-east-1a"
      size              = 30
      component         = "jenkins"
    }
    n8n = {
      availability_zone = "us-east-1a"
      size              = 5
      component         = "n8n"
    }
    prometheus = {
      availability_zone = "us-east-1b"
      size              = 20
      component         = "prometheus"
    }
    grafana = {
      availability_zone = "us-east-1b"
      size              = 5
      component         = "grafana"
    }
    alertmanager = {
      availability_zone = "us-east-1a"
      size              = 2
      component         = "alertmanager"
    }
    vault = {
      availability_zone = "us-east-1b"
      size              = 10
      component         = "vault"
      volume_type       = "gp2"
      encrypted         = false
    }
  }
}

resource "aws_ebs_volume" "persistent" {
  for_each = local.volumes

  availability_zone = each.value.availability_zone
  size              = each.value.size
  type              = try(each.value.volume_type, "gp3")
  iops              = try(each.value.volume_type, "gp3") == "gp3" ? 3000 : null
  throughput        = try(each.value.volume_type, "gp3") == "gp3" ? 125 : null
  encrypted         = try(each.value.encrypted, true)

  tags = {
    Name        = "${var.project_name}-${replace(each.key, "_", "-")}"
    Component   = each.value.component
    ManagedBy   = "terraform-persistent-storage"
    Persistence = "retain"
  }

  lifecycle {
    prevent_destroy = true
  }
}
