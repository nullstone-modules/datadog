# 0.3.2
* **Fixed:** the full permission set overran the 10,240 character limit on inline role policies,
  failing the apply with `LimitExceeded`. Permissions are now split across customer-managed policies,
  which are budgeted separately. The role's inline policy is replaced — expect it to be destroyed and
  the managed policies created in its place. If the role ends up needing more than 10 managed
  policies in total, the plan warns; that quota is self-service raisable to 25.

# 0.3.1
* **Fixed:** the integration role was missing permissions Datadog needs, including `ec2:Describe*`.
  Permissions now come from Datadog's API instead of a list maintained here, so the policy stays
  current as Datadog adds services. Expect a plan diff when Datadog changes their list.
* **Fixed:** resource collection ran without the AWS-managed `SecurityAudit` policy Datadog requires,
  causing a warning on the integration tile and incomplete metadata. Now attached automatically.
* Added `aws_integration_resource_collection` (default `true`) to turn resource collection and its
  permissions off together.

# 0.3.0
* Added CloudWatch **log subscriptions** for infrastructure log groups: `log_group_names` for exact
  names, `log_group_name_prefixes` for discovery, both empty by default. Use this for RDS Postgres
  logs — datastore blocks cannot take the `aws-datadog-logs` capability. Adds a
  `subscribed_log_groups` output.
* Added the **Datadog AWS account integration** (`enable_aws_integration`, off by default) and the
  IAM role it assumes, plus an `aws_integration_role_arn` output. Turn this on if you use the metric
  stream: streamed metrics arrive without AWS resource tags, and this is what collects the `stack`,
  `env`, and `block` tags needed to attribute them to a block.
  * Do not add streamed namespaces to `aws_integration_excluded_namespaces`. Datadog stops polling
    them on its own, and polling is what collects the tags. Defaults to Datadog's own list
    (`AWS/SQS`, `AWS/ElasticMapReduce`, `AWS/Usage`).
* **Fixed:** `metric_stream_output_format` accepted `json`, which Datadog does not ingest — records
  were delivered and silently dropped. Now rejected at plan time; use `opentelemetry1.0` or
  `opentelemetry0.7`.

# 0.2.0
* Moved into the `nullstone-modules/datadog` monorepo at `aws/datadog`. Module name unchanged.
* Switched from terraform to opentofu (`tool_name: opentofu`).
* **Fixed:** region `eu` or `gov` caused downstream agents to report to the `us1` site. Also repairs
  consumers still on an older capability version. Firehose log and metric delivery were unaffected.
* **Fixed:** the `us3` metrics intake URL pointed at the `us1` host. Now
  `event-platform-intake.us3.datadoghq.com`. Worth confirming against a real us3 org.
* Region codes are now validated. `eu` and `gov` still work as aliases for `eu1` and `us1-fed`.
* Added an optional CloudWatch metric stream (`metric_stream_namespaces`, off by default) and a
  `metric_stream_arn` output. This replaces the Datadog Agent that `aws-ecs-datadog` no longer runs.
* Added `datadog_site` and `datadog_api_url` outputs so consumers drop their own copy of the site
  table.
* Added `otlp_logs_endpoint`, `otlp_metrics_endpoint`, and `otlp_traces_endpoint` outputs for
  Datadog's agentless OTLP intake, derived from the configured site. Same-named variables override
  them.

# 0.1.7
* Released independently from https://github.com/nullstone-modules/aws-datadog, which is archived.
  See that repository for history prior to the monorepo.
