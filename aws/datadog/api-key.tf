resource "aws_secretsmanager_secret" "api_key" {
  name = "${local.resource_name}/api_key"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = var.api_key
}
