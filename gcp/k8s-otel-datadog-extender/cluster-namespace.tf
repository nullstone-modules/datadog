// This extender creates its config maps in the SAME cluster-namespace the OpenTelemetry collector
// deploys into, so the collector can mount (or merge) each fragment. The collector enforces the
// namespace match at plan time (it compares its namespace to this module's `kubernetes_namespace`
// output).
data "ns_connection" "cluster_namespace" {
  name     = "cluster-namespace"
  contract = "cluster-namespace/gcp/k8s:*"
}

locals {
  kubernetes_namespace   = data.ns_connection.cluster_namespace.outputs.kubernetes_namespace
  cluster_endpoint       = data.ns_connection.cluster_namespace.outputs.cluster_endpoint
  cluster_ca_certificate = data.ns_connection.cluster_namespace.outputs.cluster_ca_certificate
}

// GKE authenticates the kubernetes provider with a short-lived OAuth2 access token.
// See https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
data "google_client_config" "provider" {}

provider "kubernetes" {
  // GKE reports a bare host; the provider needs an https:// scheme.
  host                   = "https://${local.cluster_endpoint}"
  token                  = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(local.cluster_ca_certificate)
}
