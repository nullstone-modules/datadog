data "ns_connection" "datadog" {
  name     = "datadog"
  contract = "datastore/aws/datadog"
}

locals {
  delivery_stream_arn = data.ns_connection.datadog.outputs.logs_delivery_stream_arn
  datadog_region      = data.ns_connection.datadog.outputs.datadog_region
  api_key_secret_id   = data.ns_connection.datadog.outputs.api_key_secret_id
  app_key_secret_id   = data.ns_connection.datadog.outputs.app_key_secret_id
}

// The datadog provider (used for the logs pipeline) needs the API and App keys in plaintext.
data "aws_secretsmanager_secret_version" "app_key" {
  secret_id = local.app_key_secret_id
}

data "aws_secretsmanager_secret_version" "api_key" {
  secret_id = local.api_key_secret_id
}

locals {
  // The datastore derives `datadog_api_url` from its site code and exports it. Datastores published
  // before v0.2.0 don't have that output, so fall back to deriving it here from `datadog_region`.
  // The fallback keys match the datastore's canonical site codes.
  fallback_api_urls = {
    "us1"     = "https://app.datadoghq.com"
    "us3"     = "https://us3.datadoghq.com"
    "us5"     = "https://us5.datadoghq.com"
    "eu1"     = "https://app.datadoghq.eu"
    "ap1"     = "https://ap1.datadoghq.com"
    "us1-fed" = "https://app.ddog-gov.com"
  }

  datadog_api_url = try(
    data.ns_connection.datadog.outputs.datadog_api_url,
    lookup(local.fallback_api_urls, lower(local.datadog_region), local.fallback_api_urls["us1"]),
  )
}

provider "datadog" {
  api_key = data.aws_secretsmanager_secret_version.api_key.secret_string
  app_key = data.aws_secretsmanager_secret_version.app_key.secret_string
  api_url = local.datadog_api_url
}
