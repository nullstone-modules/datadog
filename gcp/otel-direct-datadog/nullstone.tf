terraform {
  required_providers {
    ns = {
      source = "nullstone-io/ns"
    }
    google = {
      source = "hashicorp/google"
    }
  }
}

data "ns_workspace" "this" {}

locals {
  block_name = data.ns_workspace.this.block_name
  env_name   = data.ns_workspace.this.env_name
}
