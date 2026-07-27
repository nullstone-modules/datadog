// Build the OTEL config fragment that the collector deep-merges on top of its base config.
//
// The collector merges multiple `--config` files: maps merge recursively, but lists are *replaced*.
// So this fragment contributes only NEW map keys -- its own exporters and a new `<signal>/datadog`
// pipeline per signal -- rather than touching the base pipelines. The pipelines reference processors
// (`k8sattributes`, `memory_limiter`, `batch`) and the `otlp` receiver that already exist in the
// collector's base config.
//
// Why `otlphttp` and not the native `datadog` exporter: the `datadog` exporter only exists in
// distributions built with it. ADOT ships the AWS exporters, and GKE runs Google's build -- neither
// carries it, and using it would force a custom collector image on every cluster. `otlphttp` is in
// every distribution, so this fragment works against a stock collector on both clouds.
locals {
  // The file name the fragment is mounted as, and the config map data key (collector mounts via subPath).
  datadog_filename = "datadog.yaml"

  // One exporter per signal rather than one shared exporter: each signal has its own intake endpoint,
  // and traces need a `compute_stats` header the others must not carry. `otlphttp` headers are
  // per-exporter, so per-signal headers mean per-signal exporters.
  datadog_exporters = {
    for signal in var.signals : "otlphttp/datadog_${signal}" => {
      "${signal}_endpoint" = local.signal_endpoints[signal]
      compression          = "gzip"

      headers = merge(
        { "dd-api-key" = local.datadog_api_key },
        // Without this, Datadog does not compute trace metrics (hits, errors, latency) from spans.
        signal == "traces" ? { "compute_stats" = "true" } : {},
      )
    }
  }

  datadog_fragment = {
    exporters = local.datadog_exporters
    service = {
      pipelines = {
        for signal in var.signals : "${signal}/datadog" => {
          receivers  = ["otlp"]
          processors = ["k8sattributes", "memory_limiter", "batch"]
          exporters  = ["otlphttp/datadog_${signal}"]
        }
      }
    }
  }

  // Signals that were requested but have no intake endpoint configured on the datastore.
  missing_endpoints = [for signal in var.signals : signal if trimspace(local.signal_endpoints[signal]) == ""]
}

resource "kubernetes_config_map_v1" "datadog" {
  metadata {
    name      = local.resource_name
    namespace = local.kubernetes_namespace
    labels    = local.k8s_labels
  }

  data = {
    (local.datadog_filename) = yamlencode(local.datadog_fragment)
  }

  lifecycle {
    precondition {
      condition     = length(local.missing_endpoints) == 0
      error_message = "The connected datadog datastore has no OTLP intake endpoint configured for: ${join(", ", local.missing_endpoints)}. Set otlp_<signal>_endpoint on the datastore (see https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/), or drop those signals from this module's `signals` variable."
    }
  }
}
