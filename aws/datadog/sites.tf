// Single source of truth for everything that varies by Datadog site.
//
// Before the modules were consolidated, this table existed twice with two different key sets: the
// datastore used `eu`/`gov` for the Firehose URLs, while the ECS capability used `eu1`/`us1-fed`
// for DD_SITE and fell back to us1 on a miss. A datastore configured `eu` or `gov` therefore sent
// its agents to us1. There is now one table, keyed by Datadog's own site codes, and the legacy
// codes are accepted as aliases so existing configuration keeps working.
locals {
  region_aliases = {
    "eu"  = "eu1"
    "gov" = "us1-fed"
  }

  // Normalized site code. Also what the `datadog_region` output reports, which repairs the bug for
  // consumers still running an older version of the ECS capability.
  datadog_region = lookup(local.region_aliases, lower(var.region), lower(var.region))

  datadog_sites = {
    "us1" = {
      // `site` configures agents and OTEL exporters (DD_SITE); `api_url` configures the datadog
      // terraform provider. They are not the same string.
      site                = "datadoghq.com"
      api_url             = "https://app.datadoghq.com"
      kinesis_logs_url    = "https://aws-kinesis-http-intake.logs.datadoghq.com/v1/input"
      kinesis_metrics_url = "https://awsmetrics-intake.datadoghq.com/v1/input"
    }
    "us3" = {
      site             = "us3.datadoghq.com"
      api_url          = "https://us3.datadoghq.com"
      kinesis_logs_url = "https://aws-kinesis-http-intake.logs.us3.datadoghq.com/api/v2/logs?dd-protocol=aws-kinesis-firehose"
      // The pre-consolidation module pointed us3 metrics at the us1 intake, which looks like a
      // copy/paste slip. Corrected to the us3 host, using the same form as us5 and ap1 -- the sites
      // of the same generation, which also use the `/api/v2/...?dd-protocol=aws-kinesis-firehose`
      // style for logs, as us3 does above.
      kinesis_metrics_url = "https://event-platform-intake.us3.datadoghq.com/api/v2/awsmetrics?dd-protocol=aws-kinesis-firehose"
    }
    "us5" = {
      site                = "us5.datadoghq.com"
      api_url             = "https://us5.datadoghq.com"
      kinesis_logs_url    = "https://aws-kinesis-http-intake.logs.us5.datadoghq.com/api/v2/logs?dd-protocol=aws-kinesis-firehose"
      kinesis_metrics_url = "https://event-platform-intake.us5.datadoghq.com/api/v2/awsmetrics?dd-protocol=aws-kinesis-firehose"
    }
    "eu1" = {
      site                = "datadoghq.eu"
      api_url             = "https://app.datadoghq.eu"
      kinesis_logs_url    = "https://aws-kinesis-http-intake.logs.datadoghq.eu/v1/input"
      kinesis_metrics_url = "https://awsmetrics-intake.datadoghq.eu/v1/input"
    }
    "ap1" = {
      site                = "ap1.datadoghq.com"
      api_url             = "https://ap1.datadoghq.com"
      kinesis_logs_url    = "https://aws-kinesis-http-intake.logs.ap1.datadoghq.com/api/v2/logs?dd-protocol=aws-kinesis-firehose"
      kinesis_metrics_url = "https://event-platform-intake.ap1.datadoghq.com/api/v2/awsmetrics?dd-protocol=aws-kinesis-firehose"
    }
    "us1-fed" = {
      site                = "ddog-gov.com"
      api_url             = "https://app.ddog-gov.com"
      kinesis_logs_url    = "https://aws-kinesis-http-intake.logs.ddog-gov.com/v1/input"
      kinesis_metrics_url = "https://awsmetrics-intake.ddog-gov.com/v1/input"
    }
  }

  site_config = local.datadog_sites[local.datadog_region]

  // Datadog's agentless OTLP intake is reachable at `otlp.<site>`, with a path per signal. Verified
  // against every site in the table above: each returns 401/403 without an API key, while a
  // same-depth hostname that doesn't exist returns 404.
  //
  // The variables override these, for an org whose intake lives somewhere else.
  otlp_host = "https://otlp.${local.site_config.site}"

  otlp_logs_endpoint    = var.otlp_logs_endpoint != "" ? var.otlp_logs_endpoint : "${local.otlp_host}/v1/logs"
  otlp_metrics_endpoint = var.otlp_metrics_endpoint != "" ? var.otlp_metrics_endpoint : "${local.otlp_host}/v1/metrics"
  otlp_traces_endpoint  = var.otlp_traces_endpoint != "" ? var.otlp_traces_endpoint : "${local.otlp_host}/v1/traces"
}
