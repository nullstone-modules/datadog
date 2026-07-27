# datadog

Nullstone modules for delivering application telemetry — **logs, traces, and metrics** — to
[Datadog](https://docs.datadoghq.com/opentelemetry/) on AWS and GCP.

Every Datadog module lives in this repo. Each module directory is self-contained: its own
`.nullstone/module.yml`, `README.md`, `CHANGELOG.md`, `Makefile`, `.terraform.lock.hcl`, and `.tf`
files. Nothing module-scoped lives at the repo root.

## Modules

| Directory | Registered name | Kind | What it does |
|-----------|-----------------|------|--------------|
| `aws/datadog` | `aws-datadog` | datastore | API/App keys in Secrets Manager, Firehose delivery streams for logs and metrics, and an optional CloudWatch metric stream. |
| `aws/ecs-datadog` | `aws-ecs-datadog` | capability | Ships an ECS app's logs CloudWatch → Firehose → Datadog, plus the log pipeline that tags `container` and `task_id`. **Logs only.** |
| `aws/ecs-otel-datadog-agent` | `aws-ecs-otel-datadog-agent` | capability | OTLP collector sidecar on an ECS/Fargate task: traces and custom metrics from the app, plus per-container metrics from the task metadata endpoint. |
| `aws/k8s-otel-datadog-extender` | `aws-k8s-otel-datadog-extender` | datastore | OTEL config fragment adding Datadog exporters to a collector on EKS. |
| `aws/otel-direct-datadog` | `aws-otel-direct-datadog` | capability | Points an AWS app's OTEL SDK straight at Datadog's OTLP intake — no collector, no agent. |
| `gcp/datadog` | `gcp-datadog` | datastore | API/App keys in GCP Secret Manager. Same output contract as `aws-datadog`. |
| `gcp/k8s-otel-datadog-extender` | `gcp-k8s-otel-datadog-extender` | datastore | OTEL config fragment adding Datadog exporters to a collector on GKE. |
| `gcp/otel-direct-datadog` | `gcp-otel-direct-datadog` | capability | Points a GCP app's OTEL SDK straight at Datadog's OTLP intake. |

**Directory names drop the cloud prefix; registered module names keep it.** `aws/datadog` declares
`name: aws-datadog` — users reference modules by registered name, so renaming them would be a
breaking change.

## Delivery paths

**Path 1 — direct from the app.** Per-app capability, no collector, no agent.

```
aws-datadog / gcp-datadog
        ↑ datadog connection
aws-otel-direct-datadog / gcp-otel-direct-datadog
```

**Path 2 — OTEL collector extender.** Cluster-wide, covers every workload.

```
aws-datadog / gcp-datadog
        ↑ datadog connection
aws-k8s-otel-datadog-extender / gcp-k8s-otel-datadog-extender
        ↑ extender connection
aws-eks-otel-adot / gcp-gke-otel-collector
```

**Path 3 — ECS/Fargate OTLP sidecar.**

```
aws-datadog
        ↑ datadog connection
aws-ecs-datadog (logs)  +  aws-ecs-otel-datadog-agent (traces, metrics)
```

## Which signal comes from where

Paths can be combined, but each signal should have exactly one owner or you pay Datadog twice for
the same data.

| Setup | Logs | Traces | Metrics |
|-------|------|--------|---------|
| `aws-ecs-datadog` alone | Firehose | — | Datastore metric stream, if enabled |
| `aws-ecs-datadog` + `aws-ecs-otel-datadog-agent` | Firehose | Sidecar | Sidecar (container + custom) |
| k8s extender | Collector | Collector | Collector |
| Direct capability | App SDK | App SDK | App SDK |

`aws-ecs-otel-datadog-agent` deliberately ships **no** logs pipeline by default, so it can sit
alongside `aws-ecs-datadog` without double-billing log ingest.

## Agentless OTLP intake

The k8s extenders and both direct capabilities deliver to Datadog's **agentless OTLP intake** at
`https://otlp.<site>/v1/<signal>`, derived from the datastore's `region`. Nothing to configure in the
normal case; per-signal overrides exist on the datastore for orgs whose intake lives elsewhere.

Datadog gates access to that intake per organization — the endpoints exist for every site, but yours
may not be enabled. See the datastore README.

`aws-ecs-datadog` and `aws-ecs-otel-datadog-agent` do **not** use the agentless intake and work
without it.

## Versioning

A single `v*` tag publishes every module in this repo at that version. Lockstep versioning is a
deliberate tradeoff: a module that didn't change still ships a new version with an empty changelog
entry. There is no path filtering and no per-module tag prefixes.

The series starts at `v0.2.0`, above the last independent releases of `aws-datadog` (v0.1.7) and
`aws-ecs-datadog` (v0.1.3).

## History

`aws-datadog` and `aws-ecs-datadog` previously lived in their own repositories. Those repos are
archived; their history stays there.

* https://github.com/nullstone-modules/aws-datadog
* https://github.com/nullstone-modules/aws-ecs-datadog
