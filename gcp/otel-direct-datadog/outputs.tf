output "env" {
  value       = concat(local.endpoint_env, local.tuning_env)
  description = "list(object({ name: string, value: string })) ||| Standard OTEL env vars to inject into the app so its OTEL SDK exports directly to Datadog."
}

output "secrets" {
  value       = local.header_secrets
  sensitive   = true
  description = "list(object({ name: string, value: string })) ||| Secret env vars to inject into the app; carry the Datadog API key in the per-signal OTLP headers."
}
