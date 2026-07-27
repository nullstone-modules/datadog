// The per-site intake URLs live in sites.tf alongside DD_SITE and the API URL.

resource "aws_kinesis_firehose_delivery_stream" "metrics" {
  name        = "${local.resource_name}-metrics"
  tags        = local.tags
  destination = "http_endpoint"

  http_endpoint_configuration {
    url                = local.site_config.kinesis_metrics_url
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
