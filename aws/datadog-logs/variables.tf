variable "app_metadata" {
  description = <<EOF
Nullstone automatically injects metadata from the app module into this module through this variable.
This variable is a reserved variable for capabilities.
EOF

  type    = map(string)
  default = {}
}

variable "app_type" {
  type        = string
  default     = "auto"
  description = <<EOF
Which log stream format the Datadog pipeline should parse: `ecs`, `lambda`, or `auto`.

`auto` (the default) detects it from the app's metadata — `function_name` means Lambda,
`task_definition_name` means ECS/Fargate. Set it explicitly only if detection gets it wrong.
EOF

  validation {
    condition     = contains(["auto", "ecs", "lambda"], var.app_type)
    error_message = "app_type must be one of: auto, ecs, lambda."
  }
}

locals {
  log_group_name = var.app_metadata["log_group_name"]

  // Every app module that can attach this capability publishes one of these keys. `unknown` is
  // caught by a precondition in subscription.tf rather than silently parsing the wrong format.
  detected_app_type = (
    contains(keys(var.app_metadata), "function_name") ? "lambda" :
    contains(keys(var.app_metadata), "task_definition_name") ? "ecs" :
    "unknown"
  )

  app_type  = var.app_type == "auto" ? local.detected_app_type : var.app_type
  is_ecs    = local.app_type == "ecs"
  is_lambda = local.app_type == "lambda"
}
