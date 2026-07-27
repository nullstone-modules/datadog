// Both pipelines remap Datadog's `service` onto the Nullstone block name -- without it, `service`
// is the CloudWatch log group name. They differ only in how they parse the log stream name, which
// is where each runtime hides its useful identifiers.
//
// Only one is created; the other's count is 0.

// ECS/Fargate log streams look like `api/main/63de953809f14bb2a987eab110985d6e`
// (`<stream-prefix>/<container>/<task-id>`).
resource "datadog_logs_custom_pipeline" "ecs" {
  count = local.is_ecs ? 1 : 0

  name       = local.resource_name
  is_enabled = true

  filter {
    query = "source:${local.log_group_name}"
  }

  processor {
    string_builder_processor {
      target             = "block"
      template           = local.block_name
      name               = "block name"
      is_enabled         = true
      is_replace_missing = true
    }
  }

  processor {
    service_remapper {
      sources    = ["block"]
      is_enabled = true
      name       = "remap service name"
    }
  }

  processor {
    // Extract container and task_id from log stream
    grok_parser {
      name       = "extract container and task_id"
      is_enabled = true
      source     = "aws.awslogs.logStream"

      samples = [
        "api/main/63de953809f14bb2a987eab110985d6e",
        "api/datadog-otel-collector/63de953809f14bb2a987eab110985d6e",
      ]

      grok {
        match_rules   = "grok_parser %%{token}/%%{token:container}/%%{token:task_id}"
        support_rules = <<EOF
token %%{regex("[^/]+")}
EOF
      }
    }
  }

  processor {
    // Remap container to tag
    attribute_remapper {
      name                 = "remap container to tag"
      is_enabled           = true
      source_type          = "attribute"
      sources              = ["container"]
      target_type          = "tag"
      target               = "container"
      preserve_source      = true
      override_on_conflict = false
    }
  }

  processor {
    // Remap task_id to tag
    attribute_remapper {
      name                 = "remap task_id to tag"
      is_enabled           = true
      source_type          = "attribute"
      sources              = ["task_id"]
      target_type          = "tag"
      target               = "task_id"
      preserve_source      = true
      override_on_conflict = false
    }
  }
}

// Lambda log streams look like `2026/07/27/[$LATEST]a1b2c3d4e5f67890abcdef1234567890`
// (`<date>/[<function-version>]<instance-id>`). The version distinguishes aliases and published
// versions; the instance id identifies the execution environment, which is the closest Lambda
// analog to an ECS task id -- useful for spotting a single misbehaving sandbox or cold starts.
resource "datadog_logs_custom_pipeline" "lambda" {
  count = local.is_lambda ? 1 : 0

  name       = local.resource_name
  is_enabled = true

  filter {
    query = "source:${local.log_group_name}"
  }

  processor {
    string_builder_processor {
      target             = "block"
      template           = local.block_name
      name               = "block name"
      is_enabled         = true
      is_replace_missing = true
    }
  }

  processor {
    service_remapper {
      sources    = ["block"]
      is_enabled = true
      name       = "remap service name"
    }
  }

  processor {
    // Extract function version and instance id from log stream
    grok_parser {
      name       = "extract version and instance_id"
      is_enabled = true
      source     = "aws.awslogs.logStream"

      samples = [
        "2026/07/27/[$LATEST]a1b2c3d4e5f67890abcdef1234567890",
        "2026/07/27/[42]a1b2c3d4e5f67890abcdef1234567890",
      ]

      grok {
        match_rules = "grok_parser %%{date_part}/\\[%%{version_part:version}\\]%%{instance_part:instance_id}"
        // Heredocs do not process backslash escapes, so `\]` here reaches Datadog as `\]`.
        // Writing `\\]` would deliver a literal double backslash and break the character class.
        support_rules = <<EOF
date_part %%{regex("[0-9]{4}/[0-9]{2}/[0-9]{2}")}
version_part %%{regex("[^\]]+")}
instance_part %%{regex(".+")}
EOF
      }
    }
  }

  processor {
    // Remap version to tag
    attribute_remapper {
      name                 = "remap version to tag"
      is_enabled           = true
      source_type          = "attribute"
      sources              = ["version"]
      target_type          = "tag"
      target               = "version"
      preserve_source      = true
      override_on_conflict = false
    }
  }

  processor {
    // Remap instance_id to tag
    attribute_remapper {
      name                 = "remap instance_id to tag"
      is_enabled           = true
      source_type          = "attribute"
      sources              = ["instance_id"]
      target_type          = "tag"
      target               = "instance_id"
      preserve_source      = true
      override_on_conflict = false
    }
  }
}
