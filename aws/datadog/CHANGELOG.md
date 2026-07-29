# 0.2.3
* Added CloudWatch **log subscriptions** for infrastructure log groups: `log_group_names` for exact
  names and `log_group_name_prefixes` for discovery, both empty by default. This is how RDS Postgres
  logs reach Datadog — datastore blocks cannot take capabilities, so the `aws-datadog-logs`
  capability (which attaches to an app) does not apply to them. Also added a `subscribed_log_groups`
  output. Nothing about the producing resource is changed; this only forwards what AWS already
  writes.
* Added the **Datadog AWS account integration** (`enable_aws_integration`, off by default) and the
  IAM role it assumes, plus an `aws_integration_role_arn` output. Metrics from the metric stream
  arrive carrying only CloudWatch's own dimensions — AWS resource tags, including the `stack`, `env`,
  and `block` tags Nullstone applies, are collected by Datadog through this role. Without it,
  streamed metrics cannot be attributed back to a block.
  * The role's permissions come from Datadog, not from a list copied into this module: the
    `datadog_integration_aws_iam_permissions_standard` and
    `..._resource_collection` data sources read the canonical set from Datadog's API, so the policy
    tracks what Datadog needs as they add services. A hand-maintained copy rots silently — the
    failure mode is a missing metric or an empty tag months later with nothing pointing at the
    policy.
  * Resource collection (`aws_integration_resource_collection`, on by default) additionally attaches
    the AWS-managed `SecurityAudit` policy. Datadog's docs require it — "To use resource collection,
    you must attach AWS's managed SecurityAudit Policy to your Datadog IAM role" — and without it
    Datadog warns on the AWS integration tile and metadata is incomplete.
  * Metric polling is left enabled, and the namespaces you stream are deliberately *not* excluded
    from it. Datadog stops polling a streamed namespace on its own, and polling is what collects the
    tags — excluding them loses attribution without saving anything. The default
    `aws_integration_excluded_namespaces` mirrors Datadog's own (`AWS/SQS`,
    `AWS/ElasticMapReduce`, `AWS/Usage`).
* **Fixed:** `metric_stream_output_format` accepted `json`, which Datadog's metric stream destination
  does not support — a stream configured that way delivers records that are silently never ingested.
  The value is now rejected at plan time. Only `opentelemetry1.0` and `opentelemetry0.7` remain.

# 0.2.0
* Moved into the `nullstone-modules/datadog` monorepo at `aws/datadog`. The module name is unchanged.
* Switched from terraform to opentofu (`tool_name: opentofu`).
* **Fixed:** a datastore configured with region `eu` or `gov` caused downstream agents to report to
  the `us1` Datadog site. The datastore and the ECS capability kept separate site tables with
  different key sets (`eu`/`gov` vs `eu1`/`us1-fed`), and the capability silently fell back to `us1`
  on a miss. There is now one canonical table, and `datadog_region` reports the normalized site code
  — which also repairs the behavior for consumers still on an older capability version. Firehose log
  and metric delivery were never affected.
* Region codes are now validated. `eu` and `gov` continue to work as aliases for `eu1` and `us1-fed`.
* Added `datadog_site` and `datadog_api_url` outputs so consumers no longer carry their own copy of
  the site table.
* Added `otlp_logs_endpoint`, `otlp_metrics_endpoint`, and `otlp_traces_endpoint` outputs for
  Datadog's agentless OTLP intake, used by the k8s extender and the direct capability. They are
  derived from the configured site as `https://otlp.<site>/v1/<signal>`; the same-named variables
  override individual endpoints for an org whose intake lives elsewhere.
* **Fixed:** the `us3` metrics intake URL pointed at the `us1` host
  (`awsmetrics-intake.datadoghq.com`), which looks like a copy/paste slip carried since the module
  was written. It now points at `event-platform-intake.us3.datadoghq.com`, matching the form used by
  `us5` and `ap1` — the sites of the same generation, which also share `us3`'s newer logs intake
  style. Worth confirming against a real us3 org.
* Added an optional CloudWatch metric stream (`metric_stream_namespaces`, off by default) feeding the
  existing metrics delivery stream, plus a `metric_stream_arn` output. This is where CloudWatch
  metrics come from now that `aws-ecs-datadog` no longer runs the Datadog Agent.

# 0.1.7
* Released independently from https://github.com/nullstone-modules/aws-datadog, which is archived.
  See that repository for history prior to the monorepo.
