// This extender creates its config maps in the SAME cluster-namespace the OpenTelemetry collector
// deploys into, so the collector can mount (or merge) each fragment. The collector enforces the
// namespace match at plan time (it compares its namespace to this module's `kubernetes_namespace`
// output).
data "ns_connection" "cluster_namespace" {
  name     = "cluster-namespace"
  contract = "cluster-namespace/aws/k8s:*"
}

locals {
  kubernetes_namespace   = data.ns_connection.cluster_namespace.outputs.kubernetes_namespace
  cluster_endpoint       = data.ns_connection.cluster_namespace.outputs.cluster_endpoint
  cluster_ca_certificate = data.ns_connection.cluster_namespace.outputs.cluster_ca_certificate
  cluster_name           = data.ns_connection.cluster_namespace.outputs.cluster_name
}

// EKS authenticates the kubernetes provider with an ephemeral cluster auth token.
ephemeral "aws_eks_cluster_auth" "cluster" {
  name = local.cluster_name
}

provider "kubernetes" {
  // EKS reports the endpoint with an https:// scheme already.
  host                   = local.cluster_endpoint
  token                  = ephemeral.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(local.cluster_ca_certificate)
}
