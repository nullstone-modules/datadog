# 0.3.3
* **Fixed:** counters and histograms never reached Datadog. OTEL SDKs default to cumulative
  temporality, which the OTLP intake rejects; the SDK is now told to prefer `delta`. Note the
  trade-off: a failed export now loses that interval's increments instead of being recovered by the
  next one.
* **Fixed:** `deployment.environment` is the deprecated attribute name; `deployment.environment.name`
  is now set as well.

# 0.2.0 (Unreleased)
* Initial release.

  The GCP counterpart to `aws-otel-direct-datadog`: configures an app's OTEL SDK to export straight
  to Datadog's OTLP intake, reading the API key from GCP Secret Manager.

  The version series starts at 0.2.0 because every module in this repository is published in lockstep
  from a single tag.
