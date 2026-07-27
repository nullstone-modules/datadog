resource "aws_secretsmanager_secret" "app_key" {
  name = "${local.resource_name}/app_key"
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "app_key" {
  secret_id     = aws_secretsmanager_secret.app_key.id
  secret_string = var.app_key
}
