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

Every GCP delivery path uses Datadog's **agentless OTLP intake**. It is per-signal and lives at
`otlp.<site>`, so all three endpoints are derived from `region`:

| Signal | Endpoint |
|--------|----------|
| logs | `https://otlp.<site>/v1/logs` |
| metrics | `https://otlp.<site>/v1/metrics` |
| traces | `https://otlp.<site>/v1/traces` |

Nothing to configure in the normal case. `otlp_logs_endpoint`, `otlp_metrics_endpoint`, and
`otlp_traces_endpoint` override individual endpoints for an org whose intake lives elsewhere.

> **Datadog grants access to the OTLP intake per organization.** The endpoints exist for every site,
> but yours may not be enabled — if telemetry is rejected, contact Datadog support. See
> https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/.

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `region` | `us1` | Datadog site code. |
| `api_key` | — | Datadog API key. Stored in Secret Manager. |
| `app_key` | — | Datadog App key. Stored in Secret Manager. |
| `otlp_logs_endpoint` | derived | Override for the OTLP logs intake endpoint. |
| `otlp_metrics_endpoint` | derived | Override for the OTLP metrics intake endpoint. |
| `otlp_traces_endpoint` | derived | Override for the OTLP traces intake endpoint. |
