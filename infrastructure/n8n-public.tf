variable "n8n_domain" {
  type        = string
  description = "Public domain used for n8n production webhooks"
  default     = "logs.weather-app-as.com"
}

resource "aws_route53_record" "n8n" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.n8n_domain
  type    = "A"

  allow_overwrite = true

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}



variable "n8n_ui_domain" {
  type        = string
  description = "Public domain used for the n8n editor UI"
  default     = "n8n.weather-app-as.com"
}

resource "aws_route53_record" "n8n_ui" {
  zone_id = data.aws_route53_zone.public.zone_id
  name    = var.n8n_ui_domain
  type    = "A"

  allow_overwrite = true

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
