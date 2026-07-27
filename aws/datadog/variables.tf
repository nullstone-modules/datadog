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
Datadog's Firehose metrics destination accepts `opentelemetry1.0` and `json`.
EOF

  validation {
    condition     = contains(["opentelemetry1.0", "opentelemetry0.7", "json"], var.metric_stream_output_format)
    error_message = "metric_stream_output_format must be one of: opentelemetry1.0, opentelemetry0.7, json."
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
