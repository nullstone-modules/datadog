variable "signals" {
  type        = list(string)
  default     = ["logs", "traces", "metrics"]
  description = <<EOF
Which telemetry signals to forward to Datadog. Any subset of `logs`, `traces`, `metrics`.
A `<signal>/datadog` pipeline is created for each entry.

Each requested signal needs its intake endpoint configured on the connected datadog datastore
(`otlp_logs_endpoint`, `otlp_metrics_endpoint`, `otlp_traces_endpoint`).
EOF

  validation {
    condition     = length(var.signals) > 0 && alltrue([for s in var.signals : contains(["logs", "traces", "metrics"], s)])
    error_message = "signals must be a non-empty subset of [\"logs\", \"traces\", \"metrics\"]."
  }
}
