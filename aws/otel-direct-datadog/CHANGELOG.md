# 0.3.3
* **Fixed:** counters and histograms never reached Datadog. OTEL SDKs default to cumulative
  temporality, which the OTLP intake rejects; the SDK is now told to prefer `delta`. Note the
  trade-off: a failed export now loses that interval's increments instead of being recovered by the
  next one.
* **Fixed:** `deployment.environment` is the deprecated attribute name; `deployment.environment.name`
  is now set as well.

# 0.2.0 (Unreleased)
* Initial release.

  Configures an app's OTEL SDK to export straight to Datadog's OTLP intake, modeled on
  `aws-otel-direct-betterstack`. Unlike that module it emits per-signal endpoint, protocol, and
  header variables, because Datadog publishes a separate intake endpoint per signal and requires a
  `compute_stats` header on traces.

  The version series starts at 0.2.0 because every module in this repository is published in lockstep
  from a single tag.
