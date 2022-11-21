provider "kubernetes" {
  experiments {
    manifest_resource = true
  }
  config_path = "~/.kube/config-walden"
}

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.16.0"
    }
    random = {
      source = "hashicorp/random"
      version = "3.4.3"
    }
  }
  required_version = ">= 1.3.0"
}

resource "kubernetes_namespace" "walden" {
  metadata {
    name = "walden"
  }
}
