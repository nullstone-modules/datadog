// The collector's configuration is generated here and handed to the container through the
// OTEL_CONFIG environment variable, which the collector reads via the `env:` config URI
// (`--config=env:OTEL_CONFIG`). ECS/Fargate has no way to mount a config file without an EFS volume
// or a custom image, so this keeps the sidecar to a single stock container with no extra storage.
locals {
  receivers = merge(
    {
      otlp = {
        protocols = {
          grpc = { endpoint = "0.0.0.0:4317" }
          http = { endpoint = "0.0.0.0:4318" }
        }
      }
    },
    local.container_metrics_enabled ? {
      // Reads the ECS task metadata endpoint (ECS_CONTAINER_METADATA_URI_V4, injected by ECS) for
      // per-container CPU, memory, network, and disk metrics.
      awsecscontainermetrics = {
        collection_interval = var.container_metrics_interval
      }
    } : {},
  )

  processors = {
    memory_limiter = {
      check_interval         = "1s"
      limit_percentage       = 65
      spike_limit_percentage = 20
    }
    batch = {
      send_batch_size     = 200
      send_batch_max_size = 200
      timeout             = "5s"
    }
    // Container metrics arrive from the task metadata endpoint with no service identity of their
    // own, so they get tagged here. Deliberately NOT applied to the OTLP pipelines: telemetry the
    // app emits carries its own resource attributes and must not be overwritten.
    "resource/ecs" = {
      attributes = [
        { key = "service.name", value = local.block_name, action = "upsert" },
        { key = "deployment.environment", value = local.env_name, action = "upsert" },
      ]
    }
  }

  exporters = {
    datadog = {
      api = {
        // Resolved by the collector at runtime from the container environment, so the key is never
        // written into this config or into Terraform state.
        key  = "$${env:DD_API_KEY}"
        site = local.datadog_site
      }
    }
  }

  otlp_pipeline_processors = ["memory_limiter", "batch"]

  otlp_pipelines = {
    for signal in var.signals : signal => {
      receivers  = ["otlp"]
      processors = local.otlp_pipeline_processors
      exporters  = ["datadog"]
    }
  }

  container_metrics_pipeline = local.container_metrics_enabled ? {
    "metrics/container" = {
      receivers  = ["awsecscontainermetrics"]
      processors = ["memory_limiter", "resource/ecs", "batch"]
      exporters  = ["datadog"]
    }
  } : {}

  collector_config = {
    receivers  = local.receivers
    processors = local.processors
    exporters  = local.exporters
    service = {
      pipelines = merge(local.otlp_pipelines, local.container_metrics_pipeline)
    }
  }

  collector_sidecar = {
    name  = "datadog-otel-collector"
    image = var.collector_image

    // The collector must never be able to take the app down with it. A crashed collector, a bad API
    // key, or a failed image pull degrades telemetry only.
    essential = false

    command = jsonencode(["--config=env:OTEL_CONFIG"])

    portMappings = jsonencode([
      { protocol = "tcp", containerPort = 4317 },
      { protocol = "tcp", containerPort = 4318 },
    ])

    environment = jsonencode([
      { name = "OTEL_CONFIG", value = yamlencode(local.collector_config) },
    ])

    secrets = jsonencode([
      { name = "DD_API_KEY", valueFrom = local.api_key_secret_id },
    ])
  }
}
