# Datadog OpenTelemetry Sidecar for ECS/Fargate

This capability attaches an **OTLP collector sidecar** to an ECS/Fargate task and points the
application at it. The collector receives traces and custom metrics from your app over OTLP,
collects per-container metrics from the ECS task metadata endpoint, and exports everything to
Datadog.

Pair it with `aws-ecs-datadog`, which owns logs.

## What it runs

A single `opentelemetry-collector-contrib` container named `datadog-otel-collector`:

* **non-essential** — a crashed collector, an invalid API key, or a failed image pull degrades
  telemetry without taking down the application task;
* **pinned image tag** via `collector_image`, so collector releases never roll out unannounced;
* listens on **:4317 (gRPC)** and **:4318 (HTTP)**;
* reads the Datadog API key from the datastore's Secrets Manager secret at task start — the key is
  never written into the collector config or into Terraform state;
* configured entirely through the `OTEL_CONFIG` environment variable (`--config=env:OTEL_CONFIG`),
  so there is no config file to mount and no EFS volume required.

## Injected env vars

| Name | Value |
|------|-------|
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4318`, or `:4317` when `use_grpc` is true |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf`, or `grpc` when `use_grpc` is true |
| `DD_ENV` | the Nullstone environment name |
| `DD_SERVICE` | the Nullstone block name |

A standard OpenTelemetry SDK picks up the first two with no code change.

## Signals

`signals` defaults to `["traces", "metrics"]`. **Logs are excluded on purpose**: `aws-ecs-datadog`
already ships this app's logs through CloudWatch and Firehose, and enabling them here as well would
send every line twice and bill you twice for ingest. Add `logs` only if the app does not attach
`aws-ecs-datadog`.

## Container metrics

`enable_container_metrics` (default `true`) turns on the `awsecscontainermetrics` receiver, which
reads the ECS task metadata endpoint for per-container CPU, memory, network, and disk metrics. This
is what replaces the container metrics the Datadog Agent reported before the ECS capability was
split — higher fidelity and cheaper than CloudWatch's service-level metrics.

Those metrics carry no service identity of their own, so a `resource` processor tags them with
`service.name` and `deployment.environment`. That processor is deliberately **not** applied to the
OTLP pipelines: telemetry your app emits carries its own resource attributes and must not be
overwritten.

## Connections

| Name | Contract | Purpose |
|------|----------|---------|
| `datadog` | `datastore/aws/datadog` | API key secret and Datadog site. |

This module does **not** use Datadog's agentless OTLP intake — it exports through the collector's
native `datadog` exporter, so it needs no special Datadog org enablement.

## Attaching alongside `aws-ecs-datadog`

The two are designed to run together and share nothing that can collide:

| | `aws-ecs-datadog` | this module |
|---|---|---|
| Containers | none | `datadog-otel-collector` |
| Ports | none | 4317, 4318 |
| IAM policy | `<resource>` (CloudWatch → Firehose role) | `<resource>-datadog-otel` |
| Env vars | none | `OTEL_EXPORTER_OTLP_*`, `DD_ENV`, `DD_SERVICE` |

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `collector_image` | `otel/opentelemetry-collector-contrib:0.157.0` | Sidecar image. Must include the `datadog` exporter and `awsecscontainermetrics` receiver. |
| `use_grpc` | `false` | Point the app at the gRPC listener instead of HTTP. |
| `signals` | `["traces", "metrics"]` | Signals to forward. |
| `enable_container_metrics` | `true` | Collect per-container metrics from the task metadata endpoint. |
| `container_metrics_interval` | `20s` | Container metric collection interval. |

## Outputs

| Name | Description |
|------|-------------|
| `env` | Env vars injected into the app. |
| `sidecars` | The collector container definition. |
