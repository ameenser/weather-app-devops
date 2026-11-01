# Allow the public ALB to reach n8n Pods on port 5678.
resource "aws_vpc_security_group_egress_rule" "alb_to_n8n" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = var.eks_cluster_security_group_id
  description                  = "Allow ALB outbound to n8n Pods"

  ip_protocol = "tcp"
  from_port   = 5678
  to_port     = 5678
}

resource "aws_vpc_security_group_ingress_rule" "n8n_from_alb" {
  security_group_id            = var.eks_cluster_security_group_id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Allow ALB traffic to n8n Pods"

  ip_protocol = "tcp"
  from_port   = 5678
  to_port     = 5678
}

resource "aws_lb_target_group" "n8n" {
  name        = "${var.project_name}-n8n-tg"
  protocol    = "HTTP"
  port        = 5678
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/healthz/readiness"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-n8n-tg"
  }
}

# Expose only production webhook paths.
# The n8n editor and webhook-test paths remain private.
resource "aws_lb_listener_rule" "n8n_https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 60
  condition {
    host_header {
      values = [var.n8n_domain]
    }
  }

  condition {
    path_pattern {
      values = ["/webhook/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.n8n.arn
  }
}



# Expose the complete n8n editor UI through a dedicated hostname.
resource "aws_lb_listener_rule" "n8n_ui_https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 61

  condition {
    host_header {
      values = [var.n8n_ui_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.n8n.arn
  }
}
