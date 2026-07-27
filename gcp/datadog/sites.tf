// Single source of truth for everything that varies by Datadog site. Mirrors `aws/datadog`, minus
// the Kinesis Firehose intake URLs — GCP has no Firehose analog, so telemetry travels over OTLP.
locals {
  region_aliases = {
    "eu"  = "eu1"
    "gov" = "us1-fed"
  }

  datadog_region = lookup(local.region_aliases, lower(var.region), lower(var.region))

  datadog_sites = {
    // `site` configures OTEL exporters (DD_SITE); `api_url` configures the datadog terraform
    // provider. They are not the same string.
    "us1"     = { site = "datadoghq.com", api_url = "https://app.datadoghq.com" }
    "us3"     = { site = "us3.datadoghq.com", api_url = "https://us3.datadoghq.com" }
    "us5"     = { site = "us5.datadoghq.com", api_url = "https://us5.datadoghq.com" }
    "eu1"     = { site = "datadoghq.eu", api_url = "https://app.datadoghq.eu" }
    "ap1"     = { site = "ap1.datadoghq.com", api_url = "https://ap1.datadoghq.com" }
    "us1-fed" = { site = "ddog-gov.com", api_url = "https://app.ddog-gov.com" }
  }

  site_config = local.datadog_sites[local.datadog_region]
}
