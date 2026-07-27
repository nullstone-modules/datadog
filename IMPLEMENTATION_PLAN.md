# NUL-157 — As built, and what's left

Card: [NUL-157](https://linear.app/nullstone/issue/NUL-157/built-in-support-for-sending-logs-traces-and-metrics-to-datadog)

All eight modules are written, formatted, validated (`tofu validate`), and provider-locked across
five platforms. Nothing has been applied against real infrastructure — see [What's left](#whats-left).

---

## Decisions

| # | Decision | Consequence |
|---|----------|-------------|
| 1 | `aws-ecs-datadog` drops the Datadog Agent entirely | Logs-only. No containers, no `env`/`sidecars` outputs. Biggest break in the release. |
| 2 | The CloudWatch metric stream lives in `aws/datadog` | A metric stream filters by *namespace* and its scope is the whole account+region — one per app would stream every `AWS/ECS` metric once per app. One per datastore workspace instead, **off by default**. |
| 3 | `aws-ecs-otel-datadog-agent` runs `opentelemetry-collector-contrib` with the native `datadog` exporter | Config inline via `--config=env:OTEL_CONFIG`; API key as `${env:DD_API_KEY}` from the sidecar `secrets` array. No config file, no `include:`, no EFS mount, no second Datadog Agent. |
| 4 | The sidecar enables `awsecscontainermetrics` by default | Per-container metrics from the ECS task metadata endpoint, replacing what the agent used to report — higher fidelity and cheaper than CloudWatch. |
| 5 | The k8s extenders emit `otlphttp` exporters against the agentless intake | `otlphttp` is in every distribution, so this works on stock ADOT **and** stock `otelcol-google`. No `collector_image` override, no changes to either collector repo. Cost: no native APM stats or host correlation; `compute_stats=true` recovers trace metrics. |
| 6 | Agentless intake access is documented, not gated on | Every module that needs it ships enablement instructions in its README. |
| 7 | Both existing modules move to `tool_name: opentofu` | Confirmed safe: `DataDog/datadog` resolves on the OpenTofu registry. `tlkamp/validation` was in the old lock file but unused by any `.tf`, so it's simply gone. |
| 8 | `aws-datadog` keeps `type: datadog/aws` and `layer: database` | Legacy manifest alignment deferred out of the breaking tag. Only `tool_name` and `source_url` changed. |
| 9 | No git history preservation | Files copied in; archived repos keep their history, root README points at them. |
| 10 | First tag `v0.2.0` | Above `aws-datadog` v0.1.7, and a breaking bump under 0.x. The unreleased `aws-ecs-datadog` 0.1.4 notes folded into 0.2.0. |
| 11 | Cloud Run sidecar out of scope | Follow-up card. |

## Delivery paths

| Path | Modules | Needs agentless intake? |
|------|---------|-------------------------|
| ECS logs | `aws/datadog` → `aws/ecs-datadog` | No |
| ECS traces + container/custom metrics | `aws/datadog` → `aws/ecs-otel-datadog-agent` | No |
| Account-wide CloudWatch metrics | `aws/datadog` with `metric_stream_namespaces` | No |
| Cluster-wide k8s | `aws|gcp/datadog` → `*-k8s-otel-datadog-extender` → ADOT / GKE collector | **Yes** |
| Direct from the app SDK | `aws|gcp/datadog` → `*-otel-direct-datadog` | **Yes** |

---

## Notes from the build

### The agentless intake is per-signal

Datadog publishes a separate intake endpoint per signal, `http/protobuf` only (**gRPC unsupported**),
authenticating with a `dd-api-key` header; traces additionally need `compute_stats=true` or Datadog
computes no trace metrics from spans. Payload limits: metrics 512 KiB compressed, logs 5.1 MiB,
traces 15 MiB.

That rules out the single `OTEL_EXPORTER_OTLP_ENDPOINT` shape the Better Stack modules use. Both
direct capabilities emit `OTEL_EXPORTER_OTLP_<SIGNAL>_{ENDPOINT,PROTOCOL,HEADERS}`, and both
extenders emit one `otlphttp/datadog_<signal>` exporter per signal — headers are per-exporter in
`otlphttp`, so per-signal headers force per-signal exporters.

**The endpoints are derived from the site.** Datadog's docs render the hostnames from a site selector
rather than publishing a table, but the pattern is `https://otlp.<site>/v1/<signal>` — confirmed for
us1 from the Datadog console, and probed for every other site: each returns 403 (auth required) with
a valid certificate, while a hostname of the same depth that doesn't exist returns 404. Both
datastores derive all three endpoints in `sites.tf`; the `otlp_*_endpoint` variables are overrides.

Consumers still check: a datastore published before v0.2.0 has no such outputs, and they fail at plan
time naming the signals whose endpoint is missing rather than silently exporting into the void.

### Fixed: EU and GovCloud reported to the wrong site

`aws-datadog` documented its region choices as `us1, us3, us5, eu, ap1, gov`, while `aws-ecs-datadog`
looked the region up in a table keyed `us1, us3, us5, eu1, ap1, us1-fed` and fell back to `us1` on a
miss. A datastore configured `eu` or `gov` therefore sent its agents to `us1`. Firehose delivery was
never affected.

There is now one canonical table in `aws/datadog/sites.tf`, `eu`/`gov` are accepted as aliases, and
`datadog_region` reports the *normalized* code — which repairs the behavior even for consumers still
running an older capability version.

### Env var collision, avoided

Both ECS capabilities are meant to be attached together, and both would otherwise emit `DD_ENV` and
`DD_SERVICE`. `aws/ecs-datadog` drops them: with no agent and no SDK endpoint on that side, nothing
consumes them there. The sidecar owns them. Container name, ports, and IAM policy names are all
distinct too (`datadog-otel-collector`, 4317/4318, `<resource>-datadog-otel`).

### `aws_tags`

`data.ns_workspace.this.tags` is deprecated in the `ns` provider; all three AWS modules now use
`aws_tags`, matching the Better Stack family. This may retag existing resources on upgrade.

---

## What's left

### Needs a decision or an external action

- [ ] **Request agentless intake access** from Datadog if the org doesn't already have it. The
      endpoints exist for every site, but access is granted per organization. Gates the extenders and
      both direct capabilities (not the ECS path).
- [ ] **Verify `metric_stream_output_format`.** Defaults to `opentelemetry1.0`; confirm that's what
      Datadog's Firehose metrics destination expects, since the delivery stream was originally built
      for Datadog Agent payloads. Low risk — the metric stream is off by default.
- [ ] **Confirm the corrected `us3` metrics intake.** Changed from the `us1` host to
      `event-platform-intake.us3.datadoghq.com/api/v2/awsmetrics?dd-protocol=aws-kinesis-firehose`,
      inferred from the `us5`/`ap1` entries — the sites of the same generation, which also share
      `us3`'s newer logs intake style. Both candidate hosts answer, so the form could not be settled
      remotely; needs a us3 org to confirm end to end.

### Release mechanics

- [ ] Add `NULLSTONE_API_KEY` to this repo's GitHub secrets.
- [ ] **Prove the publish matrix** — push `v0.2.0-rc.1` and confirm `nullstone modules publish`
      resolves `.nullstone/module.yml` relative to `working-directory`. No module uses `include:`, so
      manifest resolution is the only thing at stake.
- [ ] Tag `v0.2.0`; confirm all eight publish and no version went backwards.
- [ ] Archive `nullstone-modules/aws-datadog` and `nullstone-modules/aws-ecs-datadog` with READMEs
      pointing here.

### Verification (nothing below has been run)

- [ ] ECS: app + `aws/ecs-datadog` alone → logs land, no sidecar and no OTLP endpoint injected.
- [ ] ECS: app + both capabilities → logs via Firehose, traces + container metrics via the sidecar;
      kill the sidecar → task stays up.
- [ ] ECS: datastore with `metric_stream_namespaces = ["AWS/ECS"]` → CloudWatch metrics in Datadog,
      exactly once.
- [ ] EKS: `aws/datadog` → extender → `aws-eks-otel-adot` on its **stock ADOT image** → all three
      signals. (Confirms decision 5 removed the image dependency.)
- [ ] GKE: `gcp/datadog` → extender → `gcp-gke-otel-collector` on its **stock `otelcol-google` image**.
- [ ] Direct path on both clouds.
- [ ] Extenders coexist with each collector's native sinks (X-Ray/CloudWatch, Cloud Trace/Logging).
- [ ] EU/GovCloud regression: a datastore in `eu` yields `datadoghq.eu` everywhere downstream.

### Known carry-overs

* `ap2` is a current Datadog site with no entry in the site table. Its OTLP intake host
  (`otlp.ap2.datadoghq.com`) answers like the others, but there are no verified Firehose intake URLs
  for it and `aws/datadog` needs those, so it was left out of both datastores rather than supported
  asymmetrically.
* Three capabilities share `platform: otel` / `subplatform: datadog`, following the Better Stack
  template. Confirmed acceptable — `provider_types` and `appCategories` differentiate them.
