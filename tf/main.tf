provider "kubernetes" {
  experiments {
    manifest_resource = true
  }
  config_path = "~/.kube/config-nick"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config-nick"
  }
}

terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "2.6.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.13.1"
    }

    random = {
      source = "hashicorp/random"
      version = "3.3.2"
    }
  }
  required_version = ">= 1.2.6"
}

resource "kubernetes_namespace" "walden" {
  metadata {
    name = "walden"
  }
}
