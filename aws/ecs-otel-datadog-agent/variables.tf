variable "app_metadata" {
  description = <<EOF
Nullstone automatically injects metadata from the app module into this module through this variable.
This variable is a reserved variable for capabilities.
EOF

  type    = map(string)
  default = {}
}

locals {
  execution_role_name = var.app_metadata["execution_role_name"]
}

variable "collector_image" {
  type        = string
  default     = "otel/opentelemetry-collector-contrib:0.157.0"
  description = <<EOF
The container image to run as the OTLP sidecar. It must be a distribution that includes the
`datadog` exporter and the `awsecscontainermetrics` receiver — `opentelemetry-collector-contrib`
does; the core collector and the ADOT distribution do not.

Pinned by default so collector releases never roll out unannounced; override to upgrade.
EOF
}

variable "use_grpc" {
  type        = bool
  default     = false
  description = "Enable to use gRPC instead of HTTP for the OTEL_EXPORTER_OTLP_ENDPOINT environment variable injected into the app."
}

variable "signals" {
  type        = list(string)
  default     = ["traces", "metrics"]
  description = <<EOF
Which telemetry signals the sidecar forwards to Datadog. Any subset of `logs`, `traces`, `metrics`.

`logs` is excluded by default on purpose: the `aws-ecs-datadog` capability already ships this app's
logs to Datadog through CloudWatch and Kinesis Firehose. Adding logs here as well would send every
line twice and bill you twice for ingest. Only add `logs` if this app does not attach
`aws-ecs-datadog`.
EOF

  validation {
    condition     = length(var.signals) > 0 && alltrue([for s in var.signals : contains(["logs", "traces", "metrics"], s)])
    error_message = "signals must be a non-empty subset of [\"logs\", \"traces\", \"metrics\"]."
  }
}

variable "enable_container_metrics" {
  type        = bool
  default     = true
  description = <<EOF
Collect per-container CPU, memory, network, and disk metrics from the ECS task metadata endpoint via
the `awsecscontainermetrics` receiver.

This is what replaces the container metrics the Datadog Agent used to report before the ECS
capability was split, and it is both higher fidelity and cheaper than CloudWatch's service-level
metrics. Requires `metrics` in `signals`.
EOF
}

variable "container_metrics_interval" {
  type        = string
  default     = "20s"
  description = "How often to collect container metrics from the task metadata endpoint."
}

locals {
  otlp_port     = var.use_grpc ? 4317 : 4318
  otlp_endpoint = "http://localhost:${local.otlp_port}"
  otlp_protocol = var.use_grpc ? "grpc" : "http/protobuf"

  forward_logs    = contains(var.signals, "logs")
  forward_traces  = contains(var.signals, "traces")
  forward_metrics = contains(var.signals, "metrics")

  container_metrics_enabled = var.enable_container_metrics && local.forward_metrics
}
