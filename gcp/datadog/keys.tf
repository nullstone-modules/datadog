resource "google_project_service" "secret_manager" {
  service                    = "secretmanager.googleapis.com"
  disable_dependent_services = false
  disable_on_destroy         = false
}

resource "google_secret_manager_secret" "api_key" {
  // Valid secret_id: [[a-zA-Z_0-9]+]
  secret_id = "${local.resource_name}_api_key"
  labels    = local.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.secret_manager]
}

resource "google_secret_manager_secret_version" "api_key" {
  secret      = google_secret_manager_secret.api_key.id
  secret_data = var.api_key
}

resource "google_secret_manager_secret" "app_key" {
  secret_id = "${local.resource_name}_app_key"
  labels    = local.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.secret_manager]
}

resource "google_secret_manager_secret_version" "app_key" {
  secret      = google_secret_manager_secret.app_key.id
  secret_data = var.app_key
}
