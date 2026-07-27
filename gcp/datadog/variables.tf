variable "region" {
  description = <<EOF
Datadog site to deliver telemetry to. Choices: 'us1', 'us3', 'us5', 'eu1', 'ap1', or 'us1-fed'.
The legacy codes 'eu' and 'gov' are accepted and map to 'eu1' and 'us1-fed', matching `aws-datadog`.
EOF

  type    = string
  default = "us1"

  validation {
    condition     = contains(["us1", "us3", "us5", "eu1", "ap1", "us1-fed", "eu", "gov"], lower(var.region))
    error_message = "region must be one of: us1, us3, us5, eu1, ap1, us1-fed (or the legacy codes eu, gov)."
  }
}

variable "api_key" {
  description = "API Key to emit logs/metrics/traces to Datadog"
  type        = string
  sensitive   = true
}

variable "app_key" {
  description = "App Key to administer Datadog"
  type        = string
  sensitive   = true
}

// --- Agentless OTLP intake ---------------------------------------------------------------------
//
// Datadog's direct OTLP intake endpoints are per-signal, and their hostnames vary by Datadog site.
// Datadog's docs render them from a site selector rather than publishing a table, and access is
// granted per organization, so they are configured explicitly here rather than derived from
// `region`. Consumers fail with an actionable error when they need an endpoint that was left empty.
//
// On GCP every delivery path goes through OTLP, so at least one of these is always required.

variable "otlp_logs_endpoint" {
  type        = string
  default     = ""
  description = <<EOF
Datadog's OTLP logs intake endpoint for your site, including the `/v1/logs` path.
Find it at https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/logs/ with your site selected.
EOF
}

variable "otlp_metrics_endpoint" {
  type        = string
  default     = ""
  description = <<EOF
Datadog's OTLP metrics intake endpoint for your site, including the `/v1/metrics` path.
Find it at https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/metrics/ with your site selected.
EOF
}

variable "otlp_traces_endpoint" {
  type        = string
  default     = ""
  description = <<EOF
Datadog's OTLP traces intake endpoint for your site, including the `/v1/traces` path.
Find it at https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/traces/ with your site selected.
EOF
}
