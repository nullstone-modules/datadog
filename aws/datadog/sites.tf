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
      // Carried over verbatim from the pre-consolidation module, which pointed us3 metrics at the
      // us1 intake. Left as-is rather than silently re-pointing a working delivery stream.
      kinesis_metrics_url = "https://awsmetrics-intake.datadoghq.com/v1/input"
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
}
