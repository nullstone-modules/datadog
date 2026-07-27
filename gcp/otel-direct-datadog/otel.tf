// Datadog's OTLP intake is per-signal: each signal has its own endpoint, and traces take a header
// the others don't. That rules out the single `OTEL_EXPORTER_OTLP_ENDPOINT` most vendors use -- the
// SDK gets per-signal endpoint, protocol, and header variables instead.
//
// The intake accepts `http/protobuf` and `http/json` only; gRPC is not supported, so there is no
// protocol option here.
locals {
  forward = { for signal in ["logs", "metrics", "traces"] : signal => contains(var.signals, signal) }

  // OTEL_<SIGNAL>_EXPORTER: `otlp` when enabled, `none` when not. Logs additionally keep `console`
  // so container output (and therefore Cloud Logging) still works.
  signal_exporters = {
    logs    = local.forward.logs ? (var.keep_console_logs ? "otlp,console" : "otlp") : "none"
    metrics = local.forward.metrics ? "otlp" : "none"
    traces  = local.forward.traces ? "otlp" : "none"
  }

  // Per-signal endpoint + protocol, emitted only for the signals being forwarded.
  endpoint_env = flatten([
    for signal in var.signals : [
      {
        name  = "OTEL_EXPORTER_OTLP_${upper(signal)}_ENDPOINT"
        value = local.signal_endpoints[signal]
      },
      {
        name  = "OTEL_EXPORTER_OTLP_${upper(signal)}_PROTOCOL"
        value = "http/protobuf"
      },
    ]
  ])

  tuning_env = [
    {
      name  = "OTEL_EXPORTER_OTLP_COMPRESSION"
      value = var.compression
    },
    {
      name  = "OTEL_LOGS_EXPORTER"
      value = local.signal_exporters.logs
    },
    {
      name  = "OTEL_METRICS_EXPORTER"
      value = local.signal_exporters.metrics
    },
    {
      name  = "OTEL_METRICS_EXEMPLAR_FILTER"
      value = var.metrics_exemplar_filter
    },
    {
      name  = "OTEL_METRIC_EXPORT_INTERVAL"
      value = tostring(var.metric_export_interval)
    },
    {
      name  = "OTEL_TRACES_EXPORTER"
      value = local.signal_exporters.traces
    },
    {
      name  = "OTEL_TRACES_SAMPLER"
      value = var.traces_sampler
    },
    // Datadog derives `service` and `env` from these resource attributes.
    {
      name  = "OTEL_SERVICE_NAME"
      value = local.block_name
    },
    {
      name  = "OTEL_RESOURCE_ATTRIBUTES"
      value = "deployment.environment=${local.env_name}"
    },
  ]

  // The API key travels in a per-signal header, so it goes in the sensitive `secrets` output rather
  // than `env`. `compute_stats` rides along on traces -- without it Datadog computes no trace
  // metrics from the spans.
  header_secrets = [
    for signal in var.signals : {
      name = "OTEL_EXPORTER_OTLP_${upper(signal)}_HEADERS"
      value = join(",", concat(
        ["dd-api-key=${local.datadog_api_key}"],
        signal == "traces" && var.compute_stats ? ["compute_stats=true"] : [],
      ))
    }
  ]
}
