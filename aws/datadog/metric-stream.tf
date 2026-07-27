// Streams CloudWatch metrics into the metrics delivery stream, which forwards them to Datadog.
//
// Disabled by default (`metric_stream_namespaces = []`). A metric stream's scope is the whole
// account+region and it filters by namespace only, so exactly one should exist per environment —
// hence it lives here rather than on a per-app capability.
locals {
  metric_stream_enabled = length(var.metric_stream_namespaces) > 0
}

resource "aws_cloudwatch_metric_stream" "this" {
  count = local.metric_stream_enabled ? 1 : 0

  name          = "${local.resource_name}-metric-stream"
  tags          = local.tags
  role_arn      = aws_iam_role.metric_stream[0].arn
  firehose_arn  = aws_kinesis_firehose_delivery_stream.metrics.arn
  output_format = var.metric_stream_output_format

  dynamic "include_filter" {
    for_each = var.metric_stream_namespaces

    content {
      namespace = include_filter.value
    }
  }
}

resource "aws_iam_role" "metric_stream" {
  count = local.metric_stream_enabled ? 1 : 0

  name               = "${local.resource_name}-metric-stream"
  tags               = local.tags
  assume_role_policy = data.aws_iam_policy_document.metric_stream_assume.json
}

data "aws_iam_policy_document" "metric_stream_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["streams.metrics.cloudwatch.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "metric_stream" {
  count = local.metric_stream_enabled ? 1 : 0

  role   = aws_iam_role.metric_stream[0].id
  policy = data.aws_iam_policy_document.metric_stream.json
}

data "aws_iam_policy_document" "metric_stream" {
  statement {
    effect    = "Allow"
    resources = [aws_kinesis_firehose_delivery_stream.metrics.arn]

    actions = [
      "firehose:PutRecord",
      "firehose:PutRecordBatch",
    ]
  }
}
