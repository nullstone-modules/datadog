// The cloudwatch log group name is used as the "service" in datadog
// This pipeline will:
// - Set the block name based on this log group
// - Remap the service name to this block name
// - Extract the container name from the log stream name
// - Extract the task id from the log stream name
resource "datadog_logs_custom_pipeline" "service" {
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
        "api/datadog-agent/63de953809f14bb2a987eab110985d6e",
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
