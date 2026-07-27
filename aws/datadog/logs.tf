// The per-site intake URLs live in sites.tf alongside DD_SITE and the API URL.

resource "aws_s3_bucket" "failed_log_delivery" {
  bucket        = "${local.resource_name}-failed-log-delivery"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "failed_log_delivery" {
  depends_on = [aws_s3_bucket_ownership_controls.default]

  bucket = aws_s3_bucket.failed_log_delivery.id
  acl    = "private"
}

resource "aws_s3_bucket_ownership_controls" "default" {
  bucket = aws_s3_bucket.failed_log_delivery.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_iam_role" "log_delivery" {
  name               = "${local.resource_name}-log-delivery"
  assume_role_policy = data.aws_iam_policy_document.log_delivery_assume.json
}

data "aws_iam_policy_document" "log_delivery_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }
  }
}

resource "aws_kinesis_firehose_delivery_stream" "datadog" {
  name        = local.resource_name
  tags        = local.tags
  destination = "http_endpoint"

  http_endpoint_configuration {
    url                = local.site_config.kinesis_logs_url
    name               = "Datadog"
    access_key         = var.api_key
    buffering_size     = 1
    buffering_interval = 60
    retry_duration     = 60
    role_arn           = aws_iam_role.log_delivery.arn
    s3_backup_mode     = "FailedDataOnly"

    s3_configuration {
      bucket_arn         = aws_s3_bucket.failed_log_delivery.arn
      role_arn           = aws_iam_role.log_delivery.arn
      buffering_size     = 1
      buffering_interval = 60
      compression_format = "GZIP"
    }

    request_configuration {
      content_encoding = "GZIP"

      common_attributes {
        name  = "stack"
        value = data.ns_workspace.this.stack_name
      }

      common_attributes {
        name  = "env"
        value = data.ns_workspace.this.env_name
      }
    }
  }
}
