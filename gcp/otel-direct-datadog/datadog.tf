// Datadog credentials and intake endpoints come from a connected `gcp-datadog` datastore, which
// stores the API key in GCP Secret Manager. The key is read at apply time and emitted through the
// `secrets` output so the app module injects it as a secret env var rather than a plain one.
data "ns_connection" "datadog" {
  name     = "datadog"
  contract = "datastore/gcp/datadog"
}

locals {
  api_key_secret_id = data.ns_connection.datadog.outputs.api_key_secret_id

  // Per-signal intake endpoints, owned by the datastore. Datadog publishes a separate endpoint for
  // each signal rather than one base URL, so there is nothing to derive here.
  signal_endpoints = {
    logs    = try(data.ns_connection.datadog.outputs.otlp_logs_endpoint, "")
    metrics = try(data.ns_connection.datadog.outputs.otlp_metrics_endpoint, "")
    traces  = try(data.ns_connection.datadog.outputs.otlp_traces_endpoint, "")
  }

  missing_endpoints = [for signal in var.signals : signal if trimspace(local.signal_endpoints[signal]) == ""]
}

data "google_secret_manager_secret_version" "api_key" {
  secret = local.api_key_secret_id
}

locals {
  datadog_api_key = data.google_secret_manager_secret_version.api_key.secret_data
}

// This capability creates no infrastructure -- it only injects env vars -- so this is where the
// configuration is checked. Without it, a missing endpoint would surface as an empty
// OTEL_EXPORTER_OTLP_<SIGNAL>_ENDPOINT and telemetry would silently go nowhere.
resource "terraform_data" "validate" {
  input = join(",", var.signals)

  lifecycle {
    precondition {
      condition     = length(local.missing_endpoints) == 0
      error_message = "The connected datadog datastore has no OTLP intake endpoint configured for: ${join(", ", local.missing_endpoints)}. Set otlp_<signal>_endpoint on the datastore (see https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/), or drop those signals from this module's `signals` variable."
    }
  }
}
