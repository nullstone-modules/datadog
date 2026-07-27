# Datadog Logs (AWS)

This capability sends an application's **logs** to Datadog, for both **ECS/Fargate** and **Lambda**
apps. It adds no containers and no Lambda layers: logs already land in CloudWatch, so it subscribes
that log group to the Datadog delivery stream owned by the `aws-datadog` datastore and installs the
Datadog log pipeline that parses them.

Replaces `aws-ecs-datadog`, which is deprecated and ECS-only.

## Logs

Application logs arrive in near real-time (<1 min latency): CloudWatch → Kinesis Firehose → Datadog.

Logs are tagged with `stack`, `block`, and `env`. This module also installs a log pipeline that
remaps Datadog's `service` onto the Nullstone block name — without it, `service` is the CloudWatch
log group name — and then parses the log stream name for whatever identifies the runtime:

| App type | Stream format | Tags added |
|----------|---------------|------------|
| ECS/Fargate | `<prefix>/<container>/<task-id>` | `container`, `task_id` |
| Lambda | `<date>/[<version>]<instance-id>` | `version`, `instance_id` |

`container` is useful for filtering out sidecar output; `task_id` for telling tasks apart. On Lambda,
`version` distinguishes aliases and published versions, and `instance_id` identifies the execution
environment — the closest analog to a task id, handy for spotting a single misbehaving sandbox or
correlating cold starts.

## App type detection

`app_type` defaults to `auto`, which reads the app's metadata: `function_name` means Lambda,
`task_definition_name` means ECS/Fargate. If neither is present the module fails at plan time rather
than parsing the wrong format — set `app_type` to `ecs` or `lambda` explicitly in that case.

## Traces and metrics

This capability is logs-only. What you attach alongside it depends on the runtime:

| | ECS/Fargate | Lambda |
|---|---|---|
| Traces, custom metrics | `aws-ecs-otel-datadog-agent` (OTLP sidecar) | `aws-otel-direct-datadog` (SDK → Datadog's OTLP intake) |
| Container metrics | `aws-ecs-otel-datadog-agent` | — |
| Infrastructure metrics | `aws-datadog` metric stream (`metric_stream_namespaces`) | `aws-datadog` metric stream (`["AWS/Lambda"]`) |

Lambda cannot run sidecars, which is why the direct capability is the trace path there.

If you attach `aws-otel-direct-datadog`, leave `logs` out of its `signals` — this capability already
owns logs, and enabling both sends every line twice.

## Connections

| Name | Contract | Purpose |
|------|----------|---------|
| `datadog` | `datastore/aws/datadog` | Delivery stream ARN, API/App keys, Datadog site. |

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `app_type` | `auto` | Log stream format to parse: `auto`, `ecs`, or `lambda`. |

## Migrating from `aws-ecs-datadog`

Swap the capability. This module creates the same subscription filter and an equivalent pipeline, so
ECS apps see no change in what reaches Datadog — the pipeline is recreated under a new name, and log
delivery continues through the same Firehose stream.

`aws-ecs-datadog` remains published and functional; it is simply frozen at ECS.
