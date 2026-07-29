// Subscribes existing CloudWatch log groups to the logs delivery stream.
//
// This is the read-side counterpart to `aws-datadog-logs`, which subscribes an *app's* log group
// through a capability. Datastore blocks cannot take capabilities -- `capabilities` is defined only
// on the app definition -- so infrastructure log groups (RDS, and anything else AWS writes on your
// behalf) are subscribed from here instead.
//
// Nothing here changes the producing resource. It only forwards what AWS already writes.
//
// Off by default: both variables are empty, which creates no role and no filters.
locals {
  // Discovered groups are resolved at plan time, so a log group created in the same apply as this
  // module -- or after it -- is not picked up until the next apply. `log_group_names` is exact and
  // has no such lag, which is why the known RDS groups belong there rather than behind a prefix.
  discovered_log_group_names = flatten([
    for prefix in var.log_group_name_prefixes : data.aws_cloudwatch_log_groups.discovered[prefix].log_group_names
  ])

  subscribed_log_group_names = toset(concat(var.log_group_names, local.discovered_log_group_names))
  log_subscriptions_enabled  = length(local.subscribed_log_group_names) > 0
}

data "aws_cloudwatch_log_groups" "discovered" {
  for_each = toset(var.log_group_name_prefixes)

  log_group_name_prefix = each.value
}

data "aws_region" "current" {}

// CloudWatch Logs assumes this role to write into the delivery stream. It needs `firehose:PutRecord*`
// and nothing else.
//
// In particular it does *not* need `kms:Decrypt`, even though the RDS log groups are KMS-encrypted.
// The principal that decrypts is the CloudWatch Logs service itself, and `aws-rds-postgres` already
// grants `logs.<region>.amazonaws.com` decrypt on its key. Granting it here would mean discovering
// the key ARN of every producing module, which is exactly the coupling this module avoids.
resource "aws_iam_role" "cw_to_kinesis" {
  count = local.log_subscriptions_enabled ? 1 : 0

  name               = "${local.resource_name}-cw-to-kinesis"
  tags               = local.tags
  assume_role_policy = data.aws_iam_policy_document.cw_to_kinesis_assume.json
}

data "aws_iam_policy_document" "cw_to_kinesis_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "cw_to_kinesis" {
  count = local.log_subscriptions_enabled ? 1 : 0

  role   = aws_iam_role.cw_to_kinesis[0].id
  policy = data.aws_iam_policy_document.cw_to_kinesis.json
}

data "aws_iam_policy_document" "cw_to_kinesis" {
  statement {
    effect    = "Allow"
    resources = [aws_kinesis_firehose_delivery_stream.datadog.arn]

    actions = [
      "firehose:PutRecord",
      "firehose:PutRecordBatch",
    ]
  }
}

// A log group accepts only two subscription filters. If one of these fails with
// LimitExceededException, something else is already subscribed to that group.
resource "aws_cloudwatch_log_subscription_filter" "this" {
  for_each = local.subscribed_log_group_names

  name            = local.resource_name
  log_group_name  = each.value
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.datadog.arn
  role_arn        = aws_iam_role.cw_to_kinesis[0].arn
}
