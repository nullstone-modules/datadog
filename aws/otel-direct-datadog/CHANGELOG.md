# 0.2.0 (Unreleased)
* Initial release.

  Configures an app's OTEL SDK to export straight to Datadog's OTLP intake, modeled on
  `aws-otel-direct-betterstack`. Unlike that module it emits per-signal endpoint, protocol, and
  header variables, because Datadog publishes a separate intake endpoint per signal and requires a
  `compute_stats` header on traces.

  The version series starts at 0.2.0 because every module in this repository is published in lockstep
  from a single tag.
