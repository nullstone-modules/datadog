# Datadog (GCP)

This datastore module holds your Datadog credentials for GCP workloads. It stores the API key and
App key in GCP Secret Manager and exports the same contract as `aws-datadog`, so the OTEL extender
and the direct capability plug into either cloud without changes.

Unlike `aws-datadog`, it creates no delivery infrastructure — GCP has no Kinesis Firehose analog, so
all telemetry travels over OTLP.

## What it creates

* The Datadog **API key** and **App key**, each in GCP Secret Manager.
* Enables the Secret Manager API on the project.

## Consumers

| Module | Uses |
|--------|------|
| `gcp-k8s-otel-datadog-extender` | `api_key_secret_id`, `otlp_*_endpoint` |
| `gcp-otel-direct-datadog` | `api_key_secret_id`, `otlp_*_endpoint` |

## Datadog site

Set `region` to your Datadog site code: `us1`, `us3`, `us5`, `eu1`, `ap1`, or `us1-fed`. `DD_SITE`
and the Datadog API URL are derived from it. The legacy codes `eu` and `gov` are accepted and
normalize to `eu1` and `us1-fed`, matching `aws-datadog`.

## Agentless OTLP intake

Every GCP delivery path uses Datadog's **agentless OTLP intake**, so at least one of these is always
required:

```hcl
otlp_logs_endpoint    = "..."   # https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/logs/
otlp_metrics_endpoint = "..."   # https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/metrics/
otlp_traces_endpoint  = "..."   # https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/traces/
```

The endpoints are per-signal, their hostnames vary by Datadog site, and **Datadog grants access to
them per organization** — they are not enabled for every account by default. Open each page above
with your Datadog site selected and copy the endpoint it shows. If a page reports that your
organization lacks access, contact Datadog support to have the intake enabled.

Leave a signal's endpoint empty if you don't intend to forward it; consumers fail with an actionable
error if they need one that isn't set.

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `region` | `us1` | Datadog site code. |
| `api_key` | — | Datadog API key. Stored in Secret Manager. |
| `app_key` | — | Datadog App key. Stored in Secret Manager. |
| `otlp_logs_endpoint` | `""` | Agentless OTLP logs intake endpoint. |
| `otlp_metrics_endpoint` | `""` | Agentless OTLP metrics intake endpoint. |
| `otlp_traces_endpoint` | `""` | Agentless OTLP traces intake endpoint. |
