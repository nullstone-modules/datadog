# 0.2.0 (Unreleased)
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
* Added `otlp_logs_endpoint`, `otlp_metrics_endpoint`, and `otlp_traces_endpoint` variables and
  outputs for Datadog's agentless OTLP intake, used by the k8s extender and the direct capability.
* Added an optional CloudWatch metric stream (`metric_stream_namespaces`, off by default) feeding the
  existing metrics delivery stream, plus a `metric_stream_arn` output. This is where CloudWatch
  metrics come from now that `aws-ecs-datadog` no longer runs the Datadog Agent.

# 0.1.7
* Released independently from https://github.com/nullstone-modules/aws-datadog, which is archived.
  See that repository for history prior to the monorepo.
