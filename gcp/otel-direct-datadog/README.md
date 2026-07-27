# Datadog OpenTelemetry (Direct) — GCP

Nullstone **capability** that configures an application's OpenTelemetry SDK to export logs, traces,
and metrics **directly to Datadog's OTLP intake** — no collector, no agent, no sidecar.

Attach it to an app and it injects the standard OTEL env vars. The intake endpoints come from a
connected **datadog datastore** (`gcp-datadog`); the API key is read from GCP Secret Manager at apply
time and injected as a secret env var.

For cluster-wide delivery on GKE, see `gcp-k8s-otel-datadog-extender`. Don't attach both to the same
app — they both configure where telemetry goes.

## Why per-signal env vars

Most vendors take a single `OTEL_EXPORTER_OTLP_ENDPOINT`. Datadog does not: each signal has its own
intake endpoint, and traces take a `compute_stats` header the other signals must not carry. So this
module sets `OTEL_EXPORTER_OTLP_<SIGNAL>_ENDPOINT`, `..._PROTOCOL`, and `..._HEADERS` per signal.

Datadog's intake accepts `http/protobuf` and `http/json`. **gRPC is not supported**, so there is no
protocol option.

## Injected env vars

Plain env vars (via `env`), for each signal in `signals`:

| Name | Source |
|------|--------|
| `OTEL_EXPORTER_OTLP_<SIGNAL>_ENDPOINT` | `otlp_<signal>_endpoint` from the datastore |
| `OTEL_EXPORTER_OTLP_<SIGNAL>_PROTOCOL` | fixed: `http/protobuf` |

Plus:

| Name | Source |
|------|--------|
| `OTEL_EXPORTER_OTLP_COMPRESSION` | `compression` variable |
| `OTEL_LOGS_EXPORTER` | `otlp,console`, `otlp`, or `none` — see `signals` and `keep_console_logs` |
| `OTEL_METRICS_EXPORTER` | `otlp` or `none` |
| `OTEL_METRICS_EXEMPLAR_FILTER` | `metrics_exemplar_filter` variable |
| `OTEL_METRIC_EXPORT_INTERVAL` | `metric_export_interval` variable |
| `OTEL_TRACES_EXPORTER` | `otlp` or `none` |
| `OTEL_TRACES_SAMPLER` | `traces_sampler` variable |
| `OTEL_SERVICE_NAME` | the Nullstone block name |
| `OTEL_RESOURCE_ATTRIBUTES` | `deployment.environment=<env>` |

Secret env vars (via `secrets`), for each signal in `signals`:

| Name | Value |
|------|-------|
| `OTEL_EXPORTER_OTLP_<SIGNAL>_HEADERS` | `dd-api-key=<key>`, plus `compute_stats=true` on traces |

## Requirements

The connected `gcp-datadog` datastore must have an intake endpoint configured for every signal you
request. If one is missing, this module fails at plan time naming the signals that need it.

> **Datadog gates access to the OTLP intake per organization.** Open
> https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/ with your site selected to get the
> endpoints. If your organization doesn't have access, contact Datadog support to have it enabled.

Intake payload limits: metrics 512 KiB compressed, logs 5.1 MiB, traces 15 MiB.

## Connections

| Name | Contract | Purpose |
|------|----------|---------|
| `datadog` | `datastore/gcp/datadog` | API key secret and OTLP intake endpoints. |

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `signals` | `["logs", "traces", "metrics"]` | Signals to export. Others are set to `none`. |
| `keep_console_logs` | `true` | Keep logs on stdout as well, so Cloud Logging keeps working. |
| `compute_stats` | `true` | Send `compute_stats=true` on traces so Datadog computes trace metrics. |
| `compression` | `gzip` | OTLP payload compression: `gzip` or `none`. |
| `metrics_exemplar_filter` | `always_off` | `always_off`, `always_on`, or `trace_based`. |
| `metric_export_interval` | `60000` | Milliseconds between metric exports. |
| `traces_sampler` | `parentbased_always_on` | OTEL sampler; pair ratio samplers with `OTEL_TRACES_SAMPLER_ARG`. |

> **Logs caveat:** these env vars configure the SDK's log pipeline, but whether app log lines flow
> through it depends on the language. Java's agent and Python's auto-instrumentation
> (`OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED=true`) honor `OTEL_LOGS_EXPORTER` directly;
> Node and Go typically need an explicit log-bridge appender in code.
