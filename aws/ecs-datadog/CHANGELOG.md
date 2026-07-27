# 0.2.0 (Unreleased)

**Breaking.** This capability is now logs-only. Attach `aws-ecs-otel-datadog-agent` alongside it to
keep traces and custom metrics.

**Deprecated.** Use `aws-datadog-logs`, which does the same job and also supports Lambda apps. Once
the Datadog Agent came out of this module, the only thing left tying it to ECS was the log pipeline's
stream parsing — so it made no sense to keep a runtime in the module name. This module stays
published and functional, frozen at ECS.

* Removed the `datadog-agent` sidecar entirely, along with the IAM policy and execution-role
  attachment that let it read the Datadog API key. This module no longer adds containers to your task.
* Removed the `env` output — `OTEL_EXPORTER_OTLP_ENDPOINT`, `DD_ENV`, and `DD_SERVICE` are now
  injected by `aws-ecs-otel-datadog-agent`, which owns them so the two capabilities can be attached
  together without emitting duplicate env vars.
* Removed the `sidecars` output and the `agent_version` and `use_grpc` variables. `use_grpc` exists on
  the new sidecar capability; `agent_version` is `collector_image` there (it takes a full image reference, not just a tag).
* Container metrics now come from `aws-ecs-otel-datadog-agent` (per-container, from the ECS task
  metadata endpoint) or from the `aws-datadog` datastore's optional CloudWatch metric stream
  (`metric_stream_namespaces = ["AWS/ECS"]`, service-level).
* What is unchanged: the CloudWatch → Firehose subscription filter, the Datadog log pipeline that tags
  `container` and `task_id`, and the `service` remap.
* `datadog_api_url` is now read from the datadog connection when available, falling back to a local
  table for datastores published before v0.2.0.
* Moved into the `nullstone-modules/datadog` monorepo at `aws/ecs-datadog`. The module name is
  unchanged.
* Switched from terraform to opentofu (`tool_name: opentofu`).

Includes the previously unreleased 0.1.4 changes:

* The `datadog-agent` sidecar is no longer `essential`. Previously, a crashed agent, an invalid API key, or a failed image pull would stop the entire application task. (Moot here — the sidecar is gone — but it carried into `aws-ecs-otel-datadog-agent`.)
* Pinned the `datadog-agent` image to a specific version instead of `latest`.
* `DD_SITE` is now derived from the `datadog_region` on the datadog connection instead of being hardcoded to `datadoghq.com`. Agents in non-`us1` Datadog orgs now report to the correct site. Note that datastores configured with the legacy region codes `eu` and `gov` still resolved to `us1` until `aws-datadog` v0.2.0 normalized them.
* Removed `serverless` from `appCategories`. This capability requires `execution_role_name` in `app_metadata` and a `sidecars` output, neither of which is supported by the Lambda app modules.

# 0.1.3 (May 29, 2025)
* Updated datadog agent to forward OTEL traces with `service.name` and `deployment.environment`.

# 0.1.2 (May 28, 2025)
* Added `@container` and `@task_id` tags to logs that can be used as filters in Datadog.

# 0.1.1 (May 28, 2025)
* Allow use of gRPC listener for `OTEL_EXPORTER_OTLP_ENDPOINT` env var.

# 0.1.0 (Jun 04, 2024)
* Initial release
