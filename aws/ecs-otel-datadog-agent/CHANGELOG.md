# 0.2.0 (Unreleased)
* Initial release.

  Carries the OTLP collector role out of `aws-ecs-datadog`, which is now logs-only. Attach this
  capability alongside it to keep traces and custom metrics.

  Rather than running a second Datadog Agent next to the one `aws-ecs-datadog` used to own, this runs
  a purpose-built `opentelemetry-collector-contrib` sidecar with the native `datadog` exporter. It
  also picks up per-container metrics from the ECS task metadata endpoint, replacing what the agent
  used to report.

  The version series starts at 0.2.0 because every module in this repository is published in
  lockstep from a single tag.
