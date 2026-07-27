// See
//  - https://docs.datadoghq.com/logs/guide/send-aws-services-logs-with-the-datadog-kinesis-firehose-destination/?tab=kinesisfirehosedeliverystream
//  - https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs//SubscriptionFilters.html#DestinationKinesisExample
resource "aws_iam_role" "cw_to_kinesis" {
  name               = local.resource_name
  assume_role_policy = data.aws_iam_policy_document.cw_to_kinesis_assume.json
}

data "aws_region" "current" {}

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
  role   = aws_iam_role.cw_to_kinesis.id
  policy = data.aws_iam_policy_document.cw_to_kinesis.json
}

data "aws_iam_policy_document" "cw_to_kinesis" {
  statement {
    effect    = "Allow"
    resources = [local.delivery_stream_arn]

    actions = [
      "firehose:PutRecord",
      "firehose:PutRecordBatch",
      "kinesis:PutRecord",
      "kinesis:PutRecordBatch",
    ]
  }
}

resource "aws_cloudwatch_log_subscription_filter" "app" {
  name            = local.resource_name
  log_group_name  = local.log_group_name
  filter_pattern  = ""
  destination_arn = local.delivery_stream_arn
  role_arn        = aws_iam_role.cw_to_kinesis.arn
}
