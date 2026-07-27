# Datadog OpenTelemetry Extender (GCP Kubernetes)

This module extends an OpenTelemetry collector running on GKE so that it also exports to Datadog.
It creates no collector of its own — it publishes an **OTEL config fragment** that the collector
mounts and merges into its configuration.

```
gcp-datadog
    ↑ datadog connection
gcp-k8s-otel-datadog-extender
    ↑ extender connection
gcp-gke-otel-collector
```

## What the fragment contains

* One `otlphttp/datadog_<signal>` exporter per requested signal, pointed at Datadog's OTLP intake
  endpoint for that signal, authenticating with a `dd-api-key` header.
* One `<signal>/datadog` pipeline per requested signal, reusing the `otlp` receiver and the
  `k8sattributes` / `memory_limiter` / `batch` processors that already exist in the collector's base
  configuration.

The fragment only adds new map keys, so it extends the collector rather than replacing its existing
destinations. Telemetry keeps flowing to Cloud Trace, Cloud Logging, and Cloud Monitoring alongside
Datadog.

## Why `otlphttp` and not the `datadog` exporter

`gcp-gke-otel-collector` runs Google's collector build (`otelcol-google`), a curated distribution
that does not carry the native `datadog` exporter — and unlike the ADOT module, it has no
`collector_image` variable to override. A fragment naming an exporter the binary doesn't have makes
the collector fail to start.

`otlphttp` is present in every distribution, so this fragment works against the **stock** GKE
collector with no changes to `gcp-gke-otel-collector`.

The tradeoff: Datadog's OTLP intake does not give you the native exporter's APM stats computation or
host metadata correlation. `compute_stats=true` is set on the traces exporter, which recovers trace
metrics (hits, errors, latency).

## Per-signal exporters

Each signal has its own intake endpoint *and* its own headers — traces need `compute_stats`, the
others must not carry it. `otlphttp` headers are per-exporter, so there is one exporter per signal
rather than one shared exporter with per-signal endpoint overrides.

## Requirements

The connected `gcp-datadog` datastore supplies the intake endpoints. It derives them from its Datadog
site (`https://otlp.<site>/v1/<signal>`), so there is nothing to configure — but a datastore
published before v0.2.0 has no such outputs, and this module then fails at plan time naming the
signals that need them. Upgrade the datastore, or set `otlp_<signal>_endpoint` on it explicitly.

> **Datadog gates access to the OTLP intake per organization.** Open
> https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/ with your site selected to get the
> endpoints. If your organization doesn't have access, contact Datadog support to have it enabled.

## Connections

| Name | Contract | Purpose |
|------|----------|---------|
| `datadog` | `datastore/gcp/datadog` | API key secret and OTLP intake endpoints. |
| `cluster-namespace` | `cluster-namespace/gcp/k8s:*` | The namespace to create config maps in — must be the collector's namespace. |

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `signals` | `["logs", "traces", "metrics"]` | Signals to forward. A `<signal>/datadog` pipeline is created for each. |

## Outputs

| Name | Description |
|------|-------------|
| `collector-config-maps` | ConfigMaps to mount — this is what `gcp-gke-otel-collector` consumes. |
| `collector-config-fragments` | Structured fragments to deep-merge, for merge-based collectors. Sensitive — it embeds the API key. |
| `kubernetes_namespace` | The namespace the config maps were created in. |
