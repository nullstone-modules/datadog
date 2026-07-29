variable "region" {
  description = <<EOF
Datadog site to deliver telemetry to. Choices: 'us1', 'us3', 'us5', 'eu1', 'ap1', or 'us1-fed'.
The legacy codes 'eu' and 'gov' are still accepted and map to 'eu1' and 'us1-fed'.
EOF

  type    = string
  default = "us1"

  validation {
    condition     = contains(["us1", "us3", "us5", "eu1", "ap1", "us1-fed", "eu", "gov"], lower(var.region))
    error_message = "region must be one of: us1, us3, us5, eu1, ap1, us1-fed (or the legacy codes eu, gov)."
  }
}

variable "api_key" {
  description = "API Key to emit logs/metrics to Datadog"
  type        = string
  sensitive   = true
}

variable "app_key" {
  description = "App Key to administer Datadog"
  type        = string
  sensitive   = true
}

variable "metric_stream_namespaces" {
  type        = list(string)
  default     = []
  description = <<EOF
CloudWatch namespaces to stream to Datadog through the metrics delivery stream, e.g. `["AWS/ECS"]`.

Empty (the default) creates no metric stream at all. Enable this to get CloudWatch infrastructure
metrics into Datadog — most useful for ECS apps that do not attach the `aws-ecs-otel-datadog-agent`
capability, which collects richer per-container metrics at the source.

A CloudWatch metric stream filters by namespace, not by cluster or service, and its scope is the
whole account+region. This is why it lives on the datastore (one per environment) rather than on a
per-app capability, where every app would stream the same account-wide metrics again.
EOF
}

variable "metric_stream_output_format" {
  type        = string
  default     = "opentelemetry1.0"
  description = <<EOF
Payload format for the CloudWatch metric stream. Only used when `metric_stream_namespaces` is set.

Datadog's metric stream destination accepts OpenTelemetry only. `opentelemetry1.0` is the current
version; `opentelemetry0.7` is still accepted but may drop metrics. CloudWatch's third format,
`json`, is *not* supported by Datadog and is rejected here rather than silently ingesting nothing.

See https://docs.datadoghq.com/integrations/guide/aws-cloudwatch-metric-streams-with-kinesis-data-firehose/
EOF

  validation {
    condition     = contains(["opentelemetry1.0", "opentelemetry0.7"], var.metric_stream_output_format)
    error_message = "metric_stream_output_format must be one of: opentelemetry1.0, opentelemetry0.7. Datadog does not support the `json` output format."
  }
}

// --- Infrastructure log subscriptions -----------------------------------------------------------

variable "log_group_names" {
  type        = list(string)
  default     = []
  description = <<EOF
Exact CloudWatch log group names to forward to Datadog, e.g. the log groups an `aws-rds-postgres`
block exports as `db_log_group` and `db_upgrade_log_group`.

This is for *infrastructure* log groups. Application logs are handled by the `aws-datadog-logs`
capability, which attaches to the app itself.

Nothing about the producing resource is changed -- this only forwards what AWS already writes.
EOF
}

variable "log_group_name_prefixes" {
  type        = list(string)
  default     = []
  description = <<EOF
Prefixes of CloudWatch log groups to discover and forward, e.g. `["/aws/rds/instance/"]`.

Discovery happens at plan time, so a log group created after the last apply is not picked up until
the next one. Prefer `log_group_names` when you know the names -- it has no such lag.
EOF
}

// --- Datadog AWS integration --------------------------------------------------------------------

variable "enable_aws_integration" {
  type        = bool
  default     = false
  description = <<EOF
Create the Datadog <-> AWS account integration and the IAM role it assumes.

Enable this if you use the CloudWatch metric stream. Streamed metrics arrive without AWS resource
tags -- including the `stack`, `env`, and `block` tags Nullstone applies -- and this integration is
what collects them.

The integration is scoped to an AWS account, so exactly one environment should own it per account.
EOF
}

variable "aws_integration_role_name" {
  type        = string
  default     = ""
  description = <<EOF
Name of the IAM role Datadog assumes. Defaults to `<block-ref>-<suffix>-integration`.
Set this only if you need a stable, predictable role name.
EOF
}

variable "aws_integration_resource_collection" {
  type        = bool
  default     = true
  description = <<EOF
Collect AWS resource metadata alongside metrics, and grant the permissions that requires.

When on, the role also gets Datadog's resource-collection permission set and the AWS-managed
`SecurityAudit` policy, which Datadog's documentation requires for resource collection -- without it
Datadog warns on the AWS integration tile and metadata is incomplete.

Turn this off for a metrics-and-tags-only role with a smaller permission surface.
EOF
}

variable "aws_integration_additional_policy_arns" {
  type        = list(string)
  default     = []
  description = <<EOF
Extra IAM policy ARNs to attach to the Datadog integration role, on top of the permissions Datadog
publishes and the `SecurityAudit` policy attached for resource collection.

Most setups need nothing here. Use it for Datadog products with their own permission requirements,
such as Cloud Security Posture Management.
EOF
}

variable "aws_integration_regions" {
  type        = list(string)
  default     = []
  description = <<EOF
AWS regions Datadog should collect from. Empty (the default) means this workspace's region only,
which matches the metric stream's own regional scope.
EOF
}

variable "aws_integration_excluded_namespaces" {
  type        = list(string)
  default     = ["AWS/SQS", "AWS/ElasticMapReduce", "AWS/Usage"]
  description = <<EOF
CloudWatch namespaces Datadog should *not* poll. The default mirrors Datadog's own, which excludes
these three to keep `GetMetricData` costs down.

Do not add the namespaces you stream via `metric_stream_namespaces`. Datadog stops polling a streamed
namespace on its own, and polling is what collects the resource tags that make those metrics
attributable -- excluding them here loses the tags without saving anything.
EOF
}

variable "datadog_aws_account_id" {
  type        = string
  default     = "464622532012"
  description = <<EOF
The Datadog-owned AWS account allowed to assume the integration role. Datadog's own CloudFormation
template hardcodes this and marks it "DO NOT CHANGE" -- override it only if Datadog support tells
you to.
EOF
}

variable "aws_partition" {
  type        = string
  default     = "aws"
  description = "AWS partition for the integration role ARN: `aws`, `aws-cn`, or `aws-us-gov`."

  validation {
    condition     = contains(["aws", "aws-cn", "aws-us-gov"], var.aws_partition)
    error_message = "aws_partition must be one of: aws, aws-cn, aws-us-gov."
  }
}

// --- Agentless OTLP intake ---------------------------------------------------------------------
//
// Datadog's direct OTLP intake is per-signal and lives at `otlp.<site>/v1/<signal>`, so all three
// endpoints are derived from `region` in sites.tf. These variables exist only to override that for
// an org whose intake lives somewhere else. Used by the k8s extenders and the direct capabilities.

variable "otlp_logs_endpoint" {
  type        = string
  default     = ""
  description = <<EOF
Override for Datadog's OTLP logs intake endpoint, including the `/v1/logs` path.
Defaults to `https://otlp.<site>/v1/logs`, derived from `region`.
See https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/logs/.
EOF
}

variable "otlp_metrics_endpoint" {
  type        = string
  default     = ""
  description = <<EOF
Override for Datadog's OTLP metrics intake endpoint, including the `/v1/metrics` path.
Defaults to `https://otlp.<site>/v1/metrics`, derived from `region`.
See https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/metrics/.
EOF
}

variable "otlp_traces_endpoint" {
  type        = string
  default     = ""
  description = <<EOF
Override for Datadog's OTLP traces intake endpoint, including the `/v1/traces` path.
Defaults to `https://otlp.<site>/v1/traces`, derived from `region`.
See https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/traces/.
EOF
}
