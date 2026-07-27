# 0.2.0 (Unreleased)
* Initial release.

  The GCP counterpart to `aws-datadog`: Datadog API and App keys in GCP Secret Manager, with the same
  output contract so `gcp-k8s-otel-datadog-extender` and `gcp-otel-direct-datadog` need no per-cloud
  branching beyond the secret read.

  The version series starts at 0.2.0 because every module in this repository is published in lockstep
  from a single tag.
