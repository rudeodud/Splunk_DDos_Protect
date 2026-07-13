resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  log_bucket = var.log_bucket_name != "" ? var.log_bucket_name : "${local.name_prefix}-logs-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket" "logs" {
  provider      = aws.us_east_1
  bucket        = local.log_bucket
  force_destroy = true

  tags = {
    Name = local.log_bucket
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  provider                = aws.us_east_1
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = var.log_retention_days
    }
  }
}

resource "aws_kinesis_stream" "cloudfront_logs" {
  provider         = aws.us_east_1
  name             = "${local.name_prefix}-cloudfront-logs"
  shard_count      = 6
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

resource "aws_iam_role" "firehose" {
  provider = aws.us_east_1
  name     = "${local.name_prefix}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "firehose.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "firehose" {
  provider = aws.us_east_1
  name     = "${local.name_prefix}-firehose-policy"
  role     = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.cloudfront_logs.arn
      }
    ]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "cloudfront_logs" {
  provider    = aws.us_east_1
  name        = "${local.name_prefix}-cloudfront-firehose"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.cloudfront_logs.arn
    role_arn           = aws_iam_role.firehose.arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = aws_s3_bucket.logs.arn
    prefix              = "cloudfront/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/cloudfront/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    buffering_size      = 5
    buffering_interval  = 60
    compression_format  = "GZIP"
  }
}

resource "aws_kinesis_firehose_delivery_stream" "waf_logs" {
  provider    = aws.us_east_1
  name        = "aws-waf-logs-${local.name_prefix}"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = aws_s3_bucket.logs.arn
    prefix              = "waf/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/waf/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    buffering_size      = 5
    buffering_interval  = 60
    compression_format  = "GZIP"
  }
}

resource "aws_iam_role" "vpc_flow_firehose" {
  name = "${local.name_prefix}-vpc-flow-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "firehose.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_firehose" {
  name = "${local.name_prefix}-vpc-flow-firehose-policy"
  role = aws_iam_role.vpc_flow_firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.logs.arn,
          "${aws_s3_bucket.logs.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "vpc_flow_logs" {
  name        = "${local.name_prefix}-vpc-flow-firehose"
  destination = "extended_s3"

  tags = {
    LogDeliveryEnabled = "true"
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.vpc_flow_firehose.arn
    bucket_arn          = aws_s3_bucket.logs.arn
    prefix              = "vpc-flow/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/vpc-flow/!{firehose:error-output-type}/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    buffering_size      = 5
    buffering_interval  = 60
    compression_format  = "GZIP"
  }
}

resource "aws_flow_log" "vpc" {
  log_destination          = aws_kinesis_firehose_delivery_stream.vpc_flow_logs.arn
  log_destination_type     = "kinesis-data-firehose"
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.main.id
  max_aggregation_interval = 60

  tags = {
    Name = "${local.name_prefix}-vpc-flow-logs"
  }
}

resource "aws_iam_role" "cloudfront_realtime_logs" {
  provider = aws.us_east_1
  name     = "${local.name_prefix}-cloudfront-rt-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudfront.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "cloudfront_realtime_logs" {
  provider = aws.us_east_1
  name     = "${local.name_prefix}-cloudfront-rt-policy"
  role     = aws_iam_role.cloudfront_realtime_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kinesis:DescribeStreamSummary",
        "kinesis:DescribeStream",
        "kinesis:PutRecord",
        "kinesis:PutRecords"
      ]
      Resource = aws_kinesis_stream.cloudfront_logs.arn
    }]
  })
}
