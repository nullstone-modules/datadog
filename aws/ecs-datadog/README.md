# Datadog Logs for ECS/Fargate

This capability sends application **logs** to Datadog for ECS (Fargate-based or EC2-based).

It adds no containers to your task. Logs already land in CloudWatch; this module subscribes that log
group to the Datadog delivery stream owned by the `aws-datadog` datastore and installs the Datadog
log pipeline that parses them.

> **Traces and metrics moved out in v0.2.0.** This capability used to run a Datadog Agent sidecar
> that doubled as an OTLP collector. See [Migrating from v0.1.x](#migrating-from-v01x).

## Logs

Application logs arrive in near real-time (<1 min latency): CloudWatch → Kinesis Firehose → Datadog.

Logs are tagged with `stack`, `block`, and `env`. This module also installs a log pipeline that:

- creates an attribute and tag `container` for the container name — useful for filtering out sidecar
  output;
- creates an attribute and tag `task_id` for the ECS task id — useful for telling tasks apart;
- remaps the Datadog `service` to the Nullstone block name.

## Traces and custom metrics

Attach **`aws-ecs-otel-datadog-agent`** alongside this capability. It runs an OTLP collector sidecar
that receives traces and custom metrics from your app and forwards them to Datadog, and it also
collects per-container metrics from the ECS task metadata endpoint.

The two capabilities are designed to run together:

| | `aws-ecs-datadog` | `aws-ecs-otel-datadog-agent` |
|---|---|---|
| Logs | ✅ CloudWatch → Firehose | ✗ (deliberately — avoids double-billing ingest) |
| Traces | ✗ | ✅ OTLP |
| Container metrics | ✗ | ✅ task metadata endpoint |
| Custom metrics | ✗ | ✅ OTLP |
| Containers added to your task | none | one, non-essential |

## Infrastructure metrics without the sidecar

If you don't attach the sidecar, get CloudWatch's ECS metrics into Datadog by enabling the metric
stream on the `aws-datadog` datastore:

```hcl
metric_stream_namespaces = ["AWS/ECS"]
```

That is per-environment rather than per-app, and gives service-level CloudWatch metrics rather than
per-container ones.

## Connections

| Name | Contract | Purpose |
|------|----------|---------|
| `datadog` | `datastore/aws/datadog` | Delivery stream ARN, API/App keys, Datadog site. |

## Migrating from v0.1.x

v0.2.0 removes the `datadog-agent` sidecar from this capability entirely. On upgrade:

* **Traces and custom metrics stop** until you attach `aws-ecs-otel-datadog-agent`. It listens on the
  same ports and injects the same `OTEL_EXPORTER_OTLP_ENDPOINT`, so no application change is needed.
* **Container metrics stop.** They come back with the sidecar, or from the datastore's metric stream
  (see above) at CloudWatch fidelity.
* **`OTEL_EXPORTER_OTLP_ENDPOINT`, `DD_ENV`, and `DD_SERVICE` are no longer injected** by this
  capability. The sidecar capability injects all three. If you attach both, nothing changes for your
  app.
* `agent_version` and `use_grpc` moved to the sidecar capability. `use_grpc` behaves identically;
  `agent_version` is now `collector_image` and takes a full image reference, since the sidecar runs an OpenTelemetry collector rather than the Datadog Agent.
* The task execution role no longer needs to read the Datadog API key secret; that IAM policy and
  its attachment are removed.
