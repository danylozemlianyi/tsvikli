resource "aws_acm_certificate" "guacamole_backend_cert" {
  domain_name       = "backend.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = "Tsvikli Backend"
  }
}

resource "aws_route53_record" "guacamole_backend_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.guacamole_backend_cert.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = var.dns_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "guacamole_backend_cert_validation" {
  certificate_arn         = aws_acm_certificate.guacamole_backend_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.guacamole_backend_cert_validation : record.fqdn]
}

resource "aws_route53_record" "backend_record" {
  zone_id = var.dns_zone_id
  name    = "backend.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.guacamole_alb.dns_name
    zone_id                = aws_lb.guacamole_alb.zone_id
    evaluate_target_health = true
  }
}
