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
* Optionally, **log subscriptions** forwarding existing CloudWatch log groups to the logs delivery
  stream (off by default).
* Optionally, the **Datadog AWS account integration** and the IAM role it assumes (off by default).

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

## Infrastructure log subscriptions

Application logs are handled by the `aws-datadog-logs` capability, which attaches to the app. That
route is not available for **infrastructure** log groups — the ones AWS writes on your behalf for
RDS and friends — because `capabilities` is defined only on the app definition; datastore blocks are
plain blocks. So those log groups are subscribed from here instead:

```hcl
log_group_names = [
  "/aws/rds/instance/my-db-abcde/postgresql",
  "/aws/rds/instance/my-db-abcde/upgrade",
]
```

`aws-rds-postgres` exports both names as `db_log_group` and `db_upgrade_log_group`.

`log_group_name_prefixes` discovers groups by prefix instead. Discovery happens at plan time, so a
group created after the last apply is not picked up until the next one — prefer exact names when you
know them.

This changes nothing about the producing resource. It forwards what AWS already writes, so the
content depends entirely on what that resource is configured to emit. For Postgres with default
parameters that means errors, fatals, deadlocks and connection failures — **not** slow queries, which
require `log_min_duration_statement` on the parameter group.

> Encrypted log groups need no extra permission here. The principal that decrypts is the CloudWatch
> Logs service itself, and `aws-rds-postgres` already grants `logs.<region>.amazonaws.com` decrypt on
> its key. A log group accepts only two subscription filters, so a `LimitExceededException` means
> something else is already subscribed.

## Datadog AWS integration

Metrics from the metric stream arrive carrying only CloudWatch's own dimensions. **AWS resource tags
— including the `stack`, `env`, and `block` tags Nullstone applies — are not part of that stream.**
Datadog collects them separately, by assuming an IAM role in your account:

```hcl
enable_aws_integration = true
```

Without this, streamed metrics land untagged and cannot be attributed back to a Nullstone block. If
you set `metric_stream_namespaces`, you almost certainly want this too.

The integration is scoped to an AWS account, so exactly one environment should own it per account.
Datadog generates the external ID; the role's trust policy consumes it, so one apply is enough.

### Permissions

The role's permissions are **read from Datadog**, not copied into this module. Two data sources —
`datadog_integration_aws_iam_permissions_standard` and `..._resource_collection` — return the
canonical set from Datadog's API, so the policy tracks what Datadog actually needs as they add
services. A list maintained by hand rots silently: the failure mode is a missing metric or an empty
tag months later, with nothing pointing back at the policy.

The trade-off is that when Datadog changes their list, a diff appears here on the next plan. That is
intended — it surfaces the change rather than hiding it.

That set does not fit in an inline role policy, so it is split across **customer-managed policies**
attached to the role. AWS caps the aggregate size of all inline policies on a role at 10,240
characters and will not raise it, so more inline policies would not have helped; managed policies are
budgeted separately at 6,144 characters each. The actions are packed by size, so the number of
policies follows the length of Datadog's list — expect one or two.

Each role can hold 10 managed policies by default. The chunks, `SecurityAudit`, and anything in
`aws_integration_additional_policy_arns` all count against that. If the total goes over, the plan
emits a warning naming the count; the quota is self-service raisable to 25.

`aws_integration_resource_collection` (on by default) also attaches the AWS-managed **SecurityAudit**
policy. Datadog's documentation requires it:

> To use resource collection, you must attach AWS's managed SecurityAudit Policy to your Datadog IAM
> role.

Enabling collection without it half-works — Datadog raises a warning on the AWS integration tile and
resource metadata comes back incomplete. Turn the variable off for a metrics-and-tags-only role with
a smaller permission surface; `SecurityAudit` and the resource-collection permissions are then both
omitted.

`aws_integration_additional_policy_arns` covers Datadog products with their own requirements, such as
Cloud Security Posture Management. Most setups need nothing there.

### Why polling is left on

It looks wasteful to keep CloudWatch metric polling enabled for namespaces you already stream. It
isn't: Datadog detects the stream and stops polling those namespaces by itself, and polling is the
mechanism that collects the tags this integration exists for. Excluding them loses attribution and
saves nothing. `aws_integration_excluded_namespaces` defaults to Datadog's own exclusions
(`AWS/SQS`, `AWS/ElasticMapReduce`, `AWS/Usage`), which are excluded to hold down `GetMetricData`
costs.

### RDS Enhanced Monitoring

Enhanced Monitoring (`monitoring_interval` on the RDS instance) writes OS-level metrics to the
account-level `RDSOSMetrics` log group. **Subscribing that group here does not produce
`aws.rds.*` metrics.** Firehose delivers it to the logs intake, so you get JSON blobs billed as logs.

Datadog converts that data with a dedicated Lambda (`Datadog-RDS-Enhanced`), which parses each record
and posts to the metrics API. There is no Firehose equivalent. If you want enhanced metrics, deploy
that function; do not add `RDSOSMetrics` to `log_group_names` expecting metrics.

## Agentless OTLP intake

The k8s extender and the direct capability deliver over Datadog's **agentless OTLP intake**. It is
per-signal and lives at `otlp.<site>`, so all three endpoints are derived from `region`:

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

Neither `aws-ecs-datadog` nor `aws-ecs-otel-datadog-agent` uses the agentless intake — you don't
need any of this to run the ECS path.

## Variables

| Name | Default | Description |
|------|---------|-------------|
| `region` | `us1` | Datadog site code. |
| `api_key` | — | Datadog API key. Stored in Secrets Manager. |
| `app_key` | — | Datadog App key. Stored in Secrets Manager. |
| `metric_stream_namespaces` | `[]` | CloudWatch namespaces to stream. Empty creates no stream. |
| `metric_stream_output_format` | `opentelemetry1.0` | Metric stream payload format. OpenTelemetry only. |
| `log_group_names` | `[]` | Exact CloudWatch log groups to forward. |
| `log_group_name_prefixes` | `[]` | Log group prefixes to discover and forward. |
| `enable_aws_integration` | `false` | Create the Datadog AWS integration and its IAM role. |
| `aws_integration_role_name` | derived | Name of the role Datadog assumes. |
| `aws_integration_regions` | `[]` | Regions Datadog collects from. Empty means this workspace's region. |
| `aws_integration_excluded_namespaces` | Datadog's defaults | Namespaces Datadog should not poll. |
| `aws_integration_resource_collection` | `true` | Collect resource metadata; attaches `SecurityAudit`. |
| `aws_integration_additional_policy_arns` | `[]` | Extra policy ARNs for the integration role. |
| `datadog_aws_account_id` | `464622532012` | Datadog-owned account allowed to assume the role. |
| `aws_partition` | `aws` | AWS partition for the role ARN. |
| `otlp_logs_endpoint` | derived | Override for the OTLP logs intake endpoint. |
| `otlp_metrics_endpoint` | derived | Override for the OTLP metrics intake endpoint. |
| `otlp_traces_endpoint` | derived | Override for the OTLP traces intake endpoint. |
