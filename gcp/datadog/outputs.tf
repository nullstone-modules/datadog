output "datadog_region" {
  value       = local.datadog_region
  description = "string ||| The configured Datadog site code for this datadog account."
}

output "datadog_site" {
  value       = local.site_config.site
  description = "string ||| The Datadog site domain (DD_SITE), e.g. `datadoghq.com`. Used by OTEL exporters."
}

output "datadog_api_url" {
  value       = local.site_config.api_url
  description = "string ||| The Datadog app/API URL, e.g. `https://app.datadoghq.com`. Used to configure the datadog terraform provider."
}

output "otlp_logs_endpoint" {
  value       = var.otlp_logs_endpoint
  description = "string ||| Datadog's agentless OTLP logs intake endpoint. Empty when not configured."
}

output "otlp_metrics_endpoint" {
  value       = var.otlp_metrics_endpoint
  description = "string ||| Datadog's agentless OTLP metrics intake endpoint. Empty when not configured."
}

output "otlp_traces_endpoint" {
  value       = var.otlp_traces_endpoint
  description = "string ||| Datadog's agentless OTLP traces intake endpoint. Empty when not configured."
}

output "api_key_secret_id" {
  value       = google_secret_manager_secret.api_key.id
  description = "string ||| The ID (projects/*/secrets/*) of the GCP Secret Manager secret containing the Datadog API key"
}

output "api_key_secret_name" {
  value       = google_secret_manager_secret.api_key.secret_id
  description = "string ||| The name of the GCP Secret Manager secret containing the Datadog API key"
}

output "app_key_secret_id" {
  value       = google_secret_manager_secret.app_key.id
  description = "string ||| The ID (projects/*/secrets/*) of the GCP Secret Manager secret containing the Datadog App key"
}

output "app_key_secret_name" {
  value       = google_secret_manager_secret.app_key.secret_id
  description = "string ||| The name of the GCP Secret Manager secret containing the Datadog App key"
}
