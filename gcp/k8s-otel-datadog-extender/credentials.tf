// Datadog credentials and intake endpoints come from a connected `gcp-datadog` datastore, which
// stores the API key in GCP Secret Manager.
//
// Datadog's OTLP intake authenticates with a `dd-api-key` header. The collector only injects
// `--config` files (it can't set env vars on its pod), so the header must be a resolved literal
// baked into the fragment -- we read the secret to its plaintext value here and use it directly in
// `datadog.tf`.
data "ns_connection" "datadog" {
  name     = "datadog"
  contract = "datastore/gcp/datadog"
}

locals {
  api_key_secret_id = data.ns_connection.datadog.outputs.api_key_secret_id

  // Per-signal intake endpoints, owned by the datastore. Empty when that signal was never
  // configured there; requesting such a signal fails with a precondition in datadog.tf.
  signal_endpoints = {
    logs    = try(data.ns_connection.datadog.outputs.otlp_logs_endpoint, "")
    metrics = try(data.ns_connection.datadog.outputs.otlp_metrics_endpoint, "")
    traces  = try(data.ns_connection.datadog.outputs.otlp_traces_endpoint, "")
  }
}

// Read the API key from Google Secret Manager.
data "google_secret_manager_secret_version" "api_key" {
  secret = local.api_key_secret_id
}

locals {
  // Plaintext API key, read from Google Secret Manager.
  datadog_api_key = data.google_secret_manager_secret_version.api_key.secret_data
}
