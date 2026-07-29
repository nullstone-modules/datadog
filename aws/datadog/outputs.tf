output "datadog_region" {
  // The normalized site code, not the raw variable: a datastore configured with the legacy `eu` or
  // `gov` code now reports `eu1` / `us1-fed`, which is what every consumer's site table expects.
  value       = local.datadog_region
  description = "string ||| The configured Datadog site code for this datadog account."
}

output "datadog_site" {
  value       = local.site_config.site
  description = "string ||| The Datadog site domain (DD_SITE), e.g. `datadoghq.com`. Used by agents and OTEL exporters."
}

output "datadog_api_url" {
  value       = local.site_config.api_url
  description = "string ||| The Datadog app/API URL, e.g. `https://app.datadoghq.com`. Used to configure the datadog terraform provider."
}

output "otlp_logs_endpoint" {
  value       = local.otlp_logs_endpoint
  description = "string ||| Datadog's agentless OTLP logs intake endpoint, defaulted from the configured Datadog site."
}

output "otlp_metrics_endpoint" {
  value       = local.otlp_metrics_endpoint
  description = "string ||| Datadog's agentless OTLP metrics intake endpoint, defaulted from the configured Datadog site."
}

output "otlp_traces_endpoint" {
  value       = local.otlp_traces_endpoint
  description = "string ||| Datadog's agentless OTLP traces intake endpoint, defaulted from the configured Datadog site."
}

output "api_key_secret_id" {
  value       = aws_secretsmanager_secret.api_key.id
  description = "string ||| The ID of the secret containing the Datadog API key"
}

output "api_key_secret_name" {
  value       = aws_secretsmanager_secret.api_key.name
  description = "string ||| The name of the secret containing the Datadog API key"
}

output "app_key_secret_id" {
  value       = aws_secretsmanager_secret.app_key.id
  description = "string ||| The ID of the secret containing the Datadog App key"
}

output "app_key_secret_name" {
  value       = aws_secretsmanager_secret.app_key.name
  description = "string ||| The name of the secret containing the Datadog App key"
}

// Deprecated
// Use logs_delivery_stream_arn instead
output "delivery_stream_arn" {
  value       = aws_kinesis_firehose_delivery_stream.datadog.arn
  description = "string ||| (Deprecated) The ARN of the kinesis firehose delivery stream that will forward logs to Datadog"
}

output "logs_delivery_stream_arn" {
  value       = aws_kinesis_firehose_delivery_stream.datadog.arn
  description = "string ||| The ARN of the kinesis firehose delivery stream that will forward logs to Datadog"
}

output "metrics_delivery_stream_arn" {
  value       = aws_kinesis_firehose_delivery_stream.metrics.arn
  description = "string ||| The ARN of the kinesis firehose delivery stream that will forward metrics to Datadog"
}

output "metric_stream_arn" {
  value       = try(aws_cloudwatch_metric_stream.this[0].arn, "")
  description = "string ||| The ARN of the CloudWatch metric stream feeding the metrics delivery stream. Empty when `metric_stream_namespaces` is not set."
}

output "subscribed_log_groups" {
  value       = sort(tolist(local.subscribed_log_group_names))
  description = "list(string) ||| CloudWatch log groups forwarded to the logs delivery stream, from `log_group_names` and `log_group_name_prefixes`."
}

output "aws_integration_role_arn" {
  value       = try(aws_iam_role.datadog_integration[0].arn, "")
  description = "string ||| The ARN of the IAM Role Datadog assumes to collect resource tags and metadata. Empty when `enable_aws_integration` is false."
}

output "delivery_role_arn" {
  value       = aws_iam_role.log_delivery.arn
  description = "string ||| The ARN of the IAM Role that has permission to deliver logs and metrics to both kinesis firehose deilvery streams"
}

output "failed_delivery_bucket_arn" {
  value       = aws_s3_bucket.failed_log_delivery.arn
  description = "string ||| The ARN of the S3 bucket where failed log delivery messages are delivered"
}
