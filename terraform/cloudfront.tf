resource "aws_cloudfront_realtime_log_config" "app" {
  provider      = aws.us_east_1
  name          = "${local.name_prefix}-realtime-logs"
  sampling_rate = 100

  fields = [
    "timestamp",
    "c-ip",
    "time-to-first-byte",
    "sc-status",
    "cs-method",
    "cs-uri-stem",
    "cs-uri-query",
    "cs-referer",
    "cs-user-agent",
    "cs-host",
    "x-edge-location",
    "x-edge-request-id",
    "x-host-header",
    "time-taken",
    "cs-protocol",
    "cs-bytes",
    "sc-bytes",
    "x-edge-response-result-type",
    "fle-encrypted-fields",
    "fle-status",
    "c-port",
    "time-to-last-byte",
    "x-edge-detailed-result-type",
    "sc-content-type",
    "sc-content-len",
    "sc-range-start",
    "sc-range-end"
  ]

  endpoint {
    stream_type = "Kinesis"

    kinesis_stream_config {
      role_arn   = aws_iam_role.cloudfront_realtime_logs.arn
      stream_arn = aws_kinesis_stream.cloudfront_logs.arn
    }
  }
}

resource "aws_cloudfront_distribution" "app" {
  enabled             = true
  comment             = "${local.name_prefix} CloudFront distribution"
  price_class         = var.cloudfront_price_class
  web_acl_id          = aws_wafv2_web_acl.cloudfront.arn
  wait_for_deployment = false

  origin {
    domain_name = aws_lb.app.dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id        = "alb-origin"
    viewer_protocol_policy  = "redirect-to-https"
    allowed_methods         = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods          = ["GET", "HEAD", "OPTIONS"]
    compress                = true
    realtime_log_config_arn = aws_cloudfront_realtime_log_config.app.arn

    forwarded_values {
      query_string = true
      headers      = ["Host", "User-Agent", "X-Forwarded-For"]

      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 60
    max_ttl     = 300
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${local.name_prefix}-cloudfront"
  }
}
