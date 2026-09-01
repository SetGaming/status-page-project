data "aws_lb" "status_page" {
  arn = "arn:aws:elasticloadbalancing:us-east-1:992382545251:loadbalancer/app/k8s-statuspa-statuspa-280fa5455b/a4b30ce830dcc726"
}

resource "aws_wafv2_web_acl" "status_page_cloudfront" {
  name  = "avivneta-status-page-dev-cloudfront-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "avivneta_common_rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 20

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "avivneta_known_bad_inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 30

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "avivneta_sqli_rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitPerIP"
    priority = 40

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "avivneta_rate_limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "avivneta_cloudfront_waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "avivneta-status-page-dev-cloudfront-waf"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudfront_distribution" "status_page" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "AvivNeta Status Page"
  aliases             = ["app.avivneta-statuspage.com"]
  price_class         = "PriceClass_100"
  wait_for_deployment = true

  web_acl_id = aws_wafv2_web_acl.status_page_cloudfront.arn

  origin {
    domain_name = data.aws_lb.status_page.dns_name
    origin_id   = "status-page-alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"

      origin_ssl_protocols = [
        "TLSv1.2"
      ]
    }
  }

  default_cache_behavior {
    target_origin_id       = "status-page-alb"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "DELETE",
      "GET",
      "HEAD",
      "OPTIONS",
      "PATCH",
      "POST",
      "PUT"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    # AWS managed CachingDisabled
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"

    # AWS managed AllViewer
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"

    compress = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.app.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = "avivneta-status-page-dev-cloudfront"
  }

  depends_on = [
    aws_acm_certificate_validation.app
  ]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id

  name = "app.avivneta-statuspage.com"
  type = "A"

  alias {
    name = aws_cloudfront_distribution.status_page.domain_name

    zone_id = aws_cloudfront_distribution.status_page.hosted_zone_id

    evaluate_target_health = false
  }

  lifecycle {
    prevent_destroy = true
  }
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.status_page.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.status_page.domain_name
}

output "cloudfront_waf_arn" {
  value = aws_wafv2_web_acl.status_page_cloudfront.arn
}
