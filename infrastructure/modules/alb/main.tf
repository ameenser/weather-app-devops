# -----------------------------
# ALB Security Group
# -----------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for public ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from internet"

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from internet"

  ip_protocol = "tcp"
  from_port   = 443
  to_port     = 443
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_argocd" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = var.eks_cluster_security_group_id
  description                  = "Allow main ALB outbound to Argo CD pods"

  ip_protocol = "tcp"
  from_port   = 8080
  to_port     = 8080
}

resource "aws_vpc_security_group_egress_rule" "alb_to_gitlab" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = var.gitlab_sg_v2_id
  description                  = "Allow ALB outbound to GitLab HTTP"

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_jenkins" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = var.jenkins_sg_v2_id
  description                  = "Allow ALB outbound to Jenkins HTTP"

  ip_protocol = "tcp"
  from_port   = 8080
  to_port     = 8080
}

resource "aws_vpc_security_group_egress_rule" "alb_to_eks_nodeport" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = var.eks_cluster_security_group_id
  description                  = "Allow ALB outbound to EKS NodePort"

  ip_protocol = "tcp"
  from_port   = var.app_node_port
  to_port     = var.app_node_port
}

resource "aws_vpc_security_group_egress_rule" "alb_to_eks_prod_nodeport" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = var.eks_cluster_security_group_id
  description                  = "Allow ALB outbound to EKS prod NodePort"

  ip_protocol = "tcp"
  from_port   = var.app_prod_node_port
  to_port     = var.app_prod_node_port
}

resource "aws_vpc_security_group_egress_rule" "alb_to_eks_staging_nodeport" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = var.eks_cluster_security_group_id
  description                  = "Allow ALB outbound to EKS staging NodePort"

  ip_protocol = "tcp"
  from_port   = var.app_staging_node_port
  to_port     = var.app_staging_node_port
}

# -----------------------------
# Allow ALB to reach targets
# -----------------------------

resource "aws_vpc_security_group_ingress_rule" "argocd_from_alb" {
  security_group_id            = var.eks_cluster_security_group_id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Allow main ALB to Argo CD pods"

  ip_protocol = "tcp"
  from_port   = 8080
  to_port     = 8080
}

resource "aws_vpc_security_group_ingress_rule" "jenkins_v2_from_alb" {
  security_group_id            = var.jenkins_sg_v2_id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Allow ALB to new Jenkins controller SG port 8080"

  ip_protocol = "tcp"
  from_port   = 8080
  to_port     = 8080
}

resource "aws_vpc_security_group_ingress_rule" "gitlab_v2_from_alb" {
  security_group_id            = var.gitlab_sg_v2_id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Allow ALB to new GitLab SG HTTP port 80"

  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "eks_nodeport_from_alb" {
  security_group_id            = var.eks_cluster_security_group_id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Allow ALB to EKS worker nodes NodePort"

  ip_protocol = "tcp"
  from_port   = var.app_node_port
  to_port     = var.app_node_port
}

resource "aws_vpc_security_group_ingress_rule" "eks_prod_nodeport_from_alb" {
  security_group_id            = var.eks_cluster_security_group_id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Allow ALB to EKS worker nodes prod NodePort"

  ip_protocol = "tcp"
  from_port   = var.app_prod_node_port
  to_port     = var.app_prod_node_port
}

resource "aws_vpc_security_group_ingress_rule" "eks_staging_nodeport_from_alb" {
  security_group_id            = var.eks_cluster_security_group_id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Allow ALB to EKS worker nodes staging NodePort"

  ip_protocol = "tcp"
  from_port   = var.app_staging_node_port
  to_port     = var.app_staging_node_port
}


# -----------------------------
# Application Load Balancer
# -----------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-q3-alb"
  load_balancer_type = "application"
  internal           = false

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = var.public_subnet_ids

  tags = {
    Name = "${var.project_name}-q3-alb"
  }
}

# -----------------------------
# Target Groups
# -----------------------------

resource "aws_lb_target_group" "argocd" {
  name        = "${var.project_name}-argocd-tg"
  protocol    = "HTTP"
  port        = 8080
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "traffic-port"
    path                = "/healthz"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-argocd-tg"
  }
}

resource "aws_lb_target_group" "jenkins" {
  name        = "${var.project_name}-jenkins-tg"
  protocol    = "HTTP"
  port        = 8080
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/login"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-jenkins-tg"
  }
}

resource "aws_lb_target_group" "gitlab" {
  name        = "${var.project_name}-gitlab-tg"
  protocol    = "HTTP"
  port        = 80
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/users/sign_in"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-gitlab-tg"
  }
}

resource "aws_lb_target_group" "eks_app" {
  name        = "${var.project_name}-eks-app-tg"
  protocol    = "HTTP"
  port        = var.app_node_port
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-eks-app-tg"
  }
}

resource "aws_lb_target_group" "eks_prod_app" {
  name        = "${var.project_name}-eks-prod-tg"
  protocol    = "HTTP"
  port        = var.app_prod_node_port
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-eks-prod-tg"
  }
}

resource "aws_lb_target_group" "eks_staging_app" {
  name        = "${var.project_name}-eks-staging-tg"
  protocol    = "HTTP"
  port        = var.app_staging_node_port
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-eks-staging-tg"
  }
}

# -----------------------------
# Attach EC2 instances to Target Groups
# -----------------------------

resource "aws_lb_target_group_attachment" "jenkins" {
  target_group_arn = aws_lb_target_group.jenkins.arn
  target_id        = var.jenkins_instance_id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "gitlab" {
  target_group_arn = aws_lb_target_group.gitlab.arn
  target_id        = var.gitlab_instance_id
  port             = 80
}

# -----------------------------
# Attach EKS Node Group ASG to ALB Target Group
# -----------------------------
resource "aws_autoscaling_attachment" "eks_app" {
  for_each = var.eks_node_group_asg_map

  autoscaling_group_name = each.value
  lb_target_group_arn    = aws_lb_target_group.eks_app.arn
}

resource "aws_autoscaling_attachment" "eks_prod_app" {
  for_each = var.eks_node_group_asg_map

  autoscaling_group_name = each.value
  lb_target_group_arn    = aws_lb_target_group.eks_prod_app.arn
}

resource "aws_autoscaling_attachment" "eks_staging_app" {
  for_each = var.eks_node_group_asg_map

  autoscaling_group_name = each.value
  lb_target_group_arn    = aws_lb_target_group.eks_staging_app.arn
}

# -----------------------------
# HTTP Listener
# -----------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404 - Not Found"
      status_code  = "404"
    }
  }
}

# -----------------------------
# HTTPS Listener
# -----------------------------
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"

  certificate_arn = var.acm_certificate_arn
  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404 - Not Found"
      status_code  = "404"
    }
  }
}
# -----------------------------
# Listener Rules
# -----------------------------

resource "aws_lb_listener_rule" "jenkins" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  condition {
    host_header {
      values = [var.jenkins_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
}

resource "aws_lb_listener_rule" "gitlab" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  condition {
    host_header {
      values = [var.gitlab_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gitlab.arn
  }
}

resource "aws_lb_listener_rule" "app" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30

  condition {
    host_header {
      values = [var.app_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_prod_app.arn
  }
}

resource "aws_lb_listener_rule" "staging_app" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 40

  condition {
    host_header {
      values = [var.app_staging_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_staging_app.arn
  }
}

# -----------------------------
# HTTPS Listener Rules
# -----------------------------

resource "aws_lb_listener_rule" "jenkins_https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  condition {
    host_header {
      values = [var.jenkins_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
}

resource "aws_lb_listener_rule" "gitlab_https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  condition {
    host_header {
      values = [var.gitlab_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gitlab.arn
  }
}

resource "aws_lb_listener_rule" "app_https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 30

  condition {
    host_header {
      values = [var.app_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_prod_app.arn
  }
}

resource "aws_lb_listener_rule" "staging_app_https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 40

  condition {
    host_header {
      values = [var.app_staging_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_staging_app.arn
  }
}

resource "aws_lb_listener_rule" "argocd_https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 50

  condition {
    host_header {
      values = [var.argocd_domain]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.argocd.arn
  }
}
