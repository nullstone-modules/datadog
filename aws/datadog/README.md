# Datadog (AWS)

This datastore module holds your Datadog credentials and creates the AWS infrastructure that
delivers telemetry to Datadog. It does not send anything on its own — attach an application
capability, or connect an OTEL collector extender, to actually move telemetry.

## When to use

The preferred way to get telemetry from AWS infrastructure into Datadog.

- **Latency:** logs and metrics arrive in near-real-time.
- **Cost:** minimal AWS infrastructure, significantly cheaper than agents or Lambda forwarders.

## What it creates

* The Datadog **API key** and **App key**, each in AWS Secrets Manager.
* A **Kinesis Firehose delivery stream for logs**, pointed at the Datadog logs intake for your site.
* A **Kinesis Firehose delivery stream for metrics**, pointed at the Datadog metrics intake.
* An S3 bucket for failed deliveries, and the IAM role Firehose assumes.
* Optionally, a **CloudWatch metric stream** feeding the metrics delivery stream (off by default).

## Consumers

| Module | Uses |
|--------|------|
| `aws-ecs-datadog` | `logs_delivery_stream_arn`, `datadog_site`, `datadog_api_url`, both key secrets |
| `aws-ecs-otel-datadog-agent` | `api_key_secret_id`, `datadog_site` |
| `aws-k8s-otel-datadog-extender` | `api_key_secret_id`, `otlp_*_endpoint` |
| `aws-otel-direct-datadog` | `api_key_secret_id`, `otlp_*_endpoint` |

## Datadog site

Set `region` to your Datadog site code: `us1`, `us3`, `us5`, `eu1`, `ap1`, or `us1-fed`. Everything
site-dependent — the Firehose intake URLs, `DD_SITE`, and the API URL used to configure the Datadog
Terraform provider — is derived from it in `sites.tf`.

The legacy codes `eu` and `gov` are still accepted and normalize to `eu1` and `us1-fed`.

> **Fixed in v0.2.0:** the datastore and the ECS capability used to keep separate site tables with
> different key sets. A datastore configured `eu` or `gov` matched neither entry in the capability's
> table, so its agents fell back to `us1` and reported to the wrong Datadog site. Firehose delivery
> was never affected. If you run in EU or GovCloud, upgrading corrects the destination.

## CloudWatch metric stream

`metric_stream_namespaces` is empty by default, which creates no metric stream at all. Set it to
stream CloudWatch metrics to Datadog:

```hcl
metric_stream_namespaces = ["AWS/ECS"]
```

A metric stream's scope is the whole account and region, and it filters by namespace — not by
cluster or service. That is why it belongs here, once per environment, rather than on a per-app
capability where every app would stream the same account-wide metrics again.

Prefer `aws-ecs-otel-datadog-agent` where you can: it collects per-container metrics straight from
the ECS task metadata endpoint, which is both higher fidelity and cheaper than CloudWatch.

## Agentless OTLP intake

The k8s extender and the direct capability deliver over Datadog's **agentless OTLP intake**. Those
endpoints are per-signal, their hostnames vary by Datadog site, and Datadog grants access per
organization — so they are configured explicitly here rather than derived from `region`:

```hcl
otlp_logs_endpoint    = "..."   # https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/logs/
otlp_metrics_endpoint = "..."   # https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/metrics/
otlp_traces_endpoint  = "..."   # https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/traces/
```

Open each page with your Datadog site selected and copy the endpoint it shows. Leave a signal's
endpoint empty if you don't intend to forward it; consumers fail with an actionable error if they
need one that isn't set.

Neither `aws-ecs-datadog` nor `aws-ecs-otel-datadog-agent` uses the agentless intake — you don't
need any of this to run the ECS path.

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `region` | `us1` | Datadog site code. |
| `api_key` | — | Datadog API key. Stored in Secrets Manager. |
| `app_key` | — | Datadog App key. Stored in Secrets Manager. |
| `metric_stream_namespaces` | `[]` | CloudWatch namespaces to stream. Empty creates no stream. |
| `metric_stream_output_format` | `opentelemetry1.0` | Metric stream payload format. |
| `otlp_logs_endpoint` | `""` | Agentless OTLP logs intake endpoint. |
| `otlp_metrics_endpoint` | `""` | Agentless OTLP metrics intake endpoint. |
| `otlp_traces_endpoint` | `""` | Agentless OTLP traces intake endpoint. |
