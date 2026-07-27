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
// Datadog's direct OTLP intake is per-signal and lives at `otlp.<site>/v1/<signal>`, so all three
// endpoints are derived from `region` in sites.tf. These variables exist only to override that for
// an org whose intake lives somewhere else.
//
// On GCP every delivery path goes through OTLP.

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
