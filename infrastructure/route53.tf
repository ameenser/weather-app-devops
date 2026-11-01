data "aws_route53_zone" "public" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.jenkins_domain
  type    = "A"

  allow_overwrite = true

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "gitlab" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.gitlab_domain
  type    = "A"

  allow_overwrite = true

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.app_domain
  type    = "A"

  allow_overwrite = true

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "staging_app" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.app_staging_domain
  type    = "A"

  allow_overwrite = true

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = false
  }
}

