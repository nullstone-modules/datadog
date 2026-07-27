# 0.2.0 (Unreleased)
* Initial release.

  Publishes an OTEL config fragment that adds Datadog exporters and per-signal pipelines to a
  collector on GKE, modeled on `gcp-k8s-otel-betterstack-extender`.

  Exports through `otlphttp` to Datadog's OTLP intake rather than the native `datadog` exporter,
  which Google's collector build does not carry — so it works against the stock GKE collector with no
  changes to `gcp-gke-otel-collector`.

  The version series starts at 0.2.0 because every module in this repository is published in lockstep
  from a single tag.
