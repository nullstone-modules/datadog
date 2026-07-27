# Datadog OpenTelemetry Extender (AWS Kubernetes)

This module extends an OpenTelemetry collector running on EKS so that it also exports to Datadog.
It creates no collector of its own — it publishes an **OTEL config fragment** that the collector
merges into its configuration.

```
aws-datadog
    ↑ datadog connection
aws-k8s-otel-datadog-extender
    ↑ extender connection
aws-eks-otel-adot
```

## What the fragment contains

* One `otlphttp/datadog_<signal>` exporter per requested signal, pointed at Datadog's OTLP intake
  endpoint for that signal, authenticating with a `dd-api-key` header.
* One `<signal>/datadog` pipeline per requested signal, reusing the `otlp` receiver and the
  `k8sattributes` / `memory_limiter` / `batch` processors that already exist in the collector's base
  configuration.

The fragment only adds new map keys, so it extends the collector rather than replacing its existing
destinations. Telemetry keeps flowing to X-Ray and CloudWatch alongside Datadog.

## Why `otlphttp` and not the `datadog` exporter

The native `datadog` exporter only exists in collector distributions built with it.
`aws-eks-otel-adot` defaults to the ADOT collector, which ships the AWS exporters only, and the GKE
collector runs Google's build — neither carries it. Using it would force a custom collector image on
every cluster.

`otlphttp` is present in every distribution, so this fragment works against a **stock** collector on
both clouds with no `collector_image` override.

The tradeoff: Datadog's OTLP intake does not give you the native exporter's APM stats computation or
host metadata correlation. `compute_stats=true` is set on the traces exporter, which recovers trace
metrics (hits, errors, latency).

## Per-signal exporters

Each signal has its own intake endpoint *and* its own headers — traces need `compute_stats`, the
others must not carry it. `otlphttp` headers are per-exporter, so there is one exporter per signal
rather than one shared exporter with per-signal endpoint overrides.

## Requirements

The connected `aws-datadog` datastore supplies the intake endpoints. It derives them from its Datadog
site (`https://otlp.<site>/v1/<signal>`), so there is nothing to configure — but a datastore
published before v0.2.0 has no such outputs, and this module then fails at plan time naming the
signals that need them. Upgrade the datastore, or set `otlp_<signal>_endpoint` on it explicitly.

> **Datadog gates access to the OTLP intake per organization.** Open
> https://docs.datadoghq.com/opentelemetry/setup/otlp_ingest/ with your site selected to get the
> endpoints. If your organization doesn't have access, contact Datadog support to have it enabled.
> The ECS delivery path (`aws-ecs-datadog` + `aws-ecs-otel-datadog-agent`) does not need it.

## Connections

| Name | Contract | Purpose |
|------|----------|---------|
| `datadog` | `datastore/aws/datadog` | API key secret and OTLP intake endpoints. |
| `cluster-namespace` | `cluster-namespace/aws/k8s:*` | The namespace to create config maps in — must be the collector's namespace. |

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `signals` | `["logs", "traces", "metrics"]` | Signals to forward. A `<signal>/datadog` pipeline is created for each. |

## Outputs

| Name | Description |
|------|-------------|
| `collector-config-maps` | ConfigMaps to mount, for mount-based collectors. |
| `collector-config-fragments` | Structured fragments to deep-merge, for merge-based collectors like ADOT. Sensitive — it embeds the API key. |
| `kubernetes_namespace` | The namespace the config maps were created in. |
