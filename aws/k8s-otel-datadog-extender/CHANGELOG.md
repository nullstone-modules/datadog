# 0.2.0 (Unreleased)
* Initial release.

  Publishes an OTEL config fragment that adds Datadog exporters and per-signal pipelines to a
  collector on EKS, modeled on `aws-k8s-otel-betterstack-extender`.

  Exports through `otlphttp` to Datadog's OTLP intake rather than the native `datadog` exporter, so
  it works against a stock ADOT collector with no `collector_image` override.

  The version series starts at 0.2.0 because every module in this repository is published in lockstep
  from a single tag.
