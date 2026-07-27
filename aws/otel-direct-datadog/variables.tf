variable "app_metadata" {
  description = <<EOF
Nullstone automatically injects metadata from the app module into this module through this variable.
This variable is a reserved variable for capabilities.
EOF

  type    = map(string)
  default = {}
}

variable "signals" {
  type        = list(string)
  default     = ["logs", "traces", "metrics"]
  description = <<EOF
Which telemetry signals the app's OTEL SDK exports to Datadog. Any subset of `logs`, `traces`,
`metrics`. Signals left out are set to `none` so the SDK doesn't try to export them.

Each requested signal needs its intake endpoint configured on the connected datadog datastore
(`otlp_logs_endpoint`, `otlp_metrics_endpoint`, `otlp_traces_endpoint`).
EOF

  validation {
    condition     = length(var.signals) > 0 && alltrue([for s in var.signals : contains(["logs", "traces", "metrics"], s)])
    error_message = "signals must be a non-empty subset of [\"logs\", \"traces\", \"metrics\"]."
  }
}

variable "keep_console_logs" {
  type        = bool
  default     = true
  description = <<EOF
Also keep logs on stdout (`OTEL_LOGS_EXPORTER=otlp,console`) so CloudWatch — and anything reading
container output — keeps working alongside Datadog. Only applies when `logs` is in `signals`.
EOF
}

variable "compute_stats" {
  type        = bool
  default     = true
  description = <<EOF
Send `compute_stats=true` on the traces intake. Without it Datadog does not compute trace metrics
(hits, errors, latency) from the spans you send.
EOF
}

variable "compression" {
  type        = string
  default     = "gzip"
  description = "Value for `OTEL_EXPORTER_OTLP_COMPRESSION`: `gzip` or `none`."

  validation {
    condition     = contains(["gzip", "none"], var.compression)
    error_message = "compression must be one of: gzip, none."
  }
}

variable "metrics_exemplar_filter" {
  type        = string
  default     = "always_off"
  description = <<EOF
Value for `OTEL_METRICS_EXEMPLAR_FILTER`: `always_off`, `always_on`, or `trace_based`.
EOF

  validation {
    condition     = contains(["always_off", "always_on", "trace_based"], var.metrics_exemplar_filter)
    error_message = "metrics_exemplar_filter must be one of: always_off, always_on, trace_based."
  }
}

variable "metric_export_interval" {
  type        = number
  default     = 60000
  description = <<EOF
Value for `OTEL_METRIC_EXPORT_INTERVAL`: the interval (in milliseconds) between metric exports.
Lower it (e.g. 15000) for more responsive dashboards at the cost of more requests.
EOF
}

variable "traces_sampler" {
  type        = string
  default     = "parentbased_always_on"
  description = <<EOF
Value for `OTEL_TRACES_SAMPLER` (e.g. `parentbased_always_on`, `always_on`, `always_off`,
`traceidratio`, `parentbased_traceidratio`). When using a ratio sampler, configure the ratio with
`OTEL_TRACES_SAMPLER_ARG` via app env variables.
EOF
}
