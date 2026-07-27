# 0.2.0 (Unreleased)
* Initial release.

  The runtime-agnostic replacement for `aws-ecs-datadog`, which is now deprecated. Handles both
  ECS/Fargate and Lambda apps: the CloudWatch → Firehose subscription is identical for either, and
  only the log pipeline's stream parsing differs. The app type is detected from `app_metadata`, with
  an `app_type` variable to override it.

  Lambda apps get `version` and `instance_id` tags where ECS apps get `container` and `task_id`. Both
  get Datadog's `service` remapped onto the Nullstone block name.

  The version series starts at 0.2.0 because every module in this repository is published in lockstep
  from a single tag.
