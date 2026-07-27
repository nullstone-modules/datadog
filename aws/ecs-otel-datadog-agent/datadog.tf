data "ns_connection" "datadog" {
  name     = "datadog"
  contract = "datastore/aws/datadog"
}

locals {
  datadog_region    = data.ns_connection.datadog.outputs.datadog_region
  api_key_secret_id = data.ns_connection.datadog.outputs.api_key_secret_id

  // The datastore derives `datadog_site` from its site code and exports it. Datastores published
  // before v0.2.0 don't have that output, so fall back to deriving it here.
  fallback_sites = {
    "us1"     = "datadoghq.com"
    "us3"     = "us3.datadoghq.com"
    "us5"     = "us5.datadoghq.com"
    "eu1"     = "datadoghq.eu"
    "ap1"     = "ap1.datadoghq.com"
    "us1-fed" = "ddog-gov.com"
  }

  datadog_site = try(
    data.ns_connection.datadog.outputs.datadog_site,
    lookup(local.fallback_sites, lower(local.datadog_region), local.fallback_sites["us1"]),
  )
}

// The sidecar reads the API key from Secrets Manager at task start, so the task execution role needs
// permission to fetch it. Scoped to this one secret.
resource "aws_iam_policy" "datadog_otel" {
  name   = "${local.resource_name}-datadog-otel"
  policy = data.aws_iam_policy_document.datadog_otel.json
}

data "aws_iam_policy_document" "datadog_otel" {
  statement {
    sid       = "AllowReadDatadogApiKey"
    effect    = "Allow"
    resources = [local.api_key_secret_id]

    actions = [
      "secretsmanager:GetSecretValue",
      "kms:Decrypt",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "execution_datadog_otel" {
  role       = local.execution_role_name
  policy_arn = aws_iam_policy.datadog_otel.arn
}
