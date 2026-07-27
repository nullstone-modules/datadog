output "env" {
  value = [
    {
      name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
      value = local.otlp_endpoint
    },
    {
      name  = "OTEL_EXPORTER_OTLP_PROTOCOL"
      value = local.otlp_protocol
    },
    {
      name  = "DD_ENV"
      value = local.env_name
    },
    {
      name  = "DD_SERVICE"
      value = local.block_name
    },
  ]
  description = "list(object({ name: string, value: string })) ||| Env vars injected into the app so its OTEL SDK exports to the sidecar on localhost."
}

output "sidecars" {
  value = [
    local.collector_sidecar,
  ]
  description = "list(any) ||| The OTLP collector sidecar to attach to the ECS task."
}
