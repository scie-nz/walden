provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
    random = {
      source = "hashicorp/random"
      version = "3.6.3"
    }
  }
}

module "namespace" {
  source = "./namespace"

  name = var.namespace
}

module "nessie_postgres" {
  count = var.nessie_postgres_internal ? 1 : 0
  source = "./postgres"

  namespace = module.namespace.name
  name = "nessie-postgres"
  image = var.image_postgres

  db = "nessie"
  storage = "1Gi"
}

resource "helm_release" "nessie" {
  name       = "nessie"
  namespace  = module.namespace.name
  repository = "https://charts.projectnessie.org/"
  chart      = "nessie"
  # latest from https://projectnessie.org/nessie-latest/
  version    = "0.102.2"

  values = [
    templatefile("${path.module}/nessie-values.yaml", {
      jdbc_url = var.nessie_postgres_internal ? "jdbc:postgresql://nessie-postgres:5432/nessie" : var.nessie_postgres_url
      jdbc_secret_name = var.nessie_postgres_internal ? "nessie-postgres" : ""
    })
  ]
}

module "minio" {
  source = "./minio"

  namespace = module.namespace.name
  name = "minio"
  image = var.image_minio

  username = var.minio_username
  password = var.minio_password
  replicas = var.minio_replicas
  mem_limit = var.minio_mem_limit

  node_selector = var.minio_node_selector
  tolerations = var.minio_tolerations

  storage = "1Gi"
  nfs_server = ""
  nfs_path = ""
}

resource "helm_release" "trino" {
  name       = "trino"
  namespace  = module.namespace.name
  repository = "https://trinodb.github.io/charts"
  chart      = "trino"
  # latest from https://github.com/trinodb/charts/
  version    = "1.36.0"

  values = [
    templatefile("${path.module}/trino-values.yaml", {
      catalogs = yamlencode(merge({
        iceberg = <<EOT
connector.name = iceberg-nessie
iceberg.catalog.type = nessie
iceberg.file-format = ORC
iceberg.nessie-catalog.uri = "http://nessie:19120/api/v2"
EOT
      }, var.trino_extra_catalogs))

      worker_replicas = var.trino_worker_replicas

      coordinator_node_selector   = var.trino_coordinator_node_selector
      coordinator_mem_limit       = var.trino_coordinator_mem_limit
      coordinator_max_heap        = var.trino_coordinator_max_heap
      coordinator_query_mem_limit = var.trino_coordinator_query_mem_limit

      worker_node_selector   = var.trino_worker_node_selector
      worker_mem_limit       = var.trino_worker_mem_limit
      worker_max_heap        = var.trino_worker_max_heap
      worker_query_mem_limit = var.trino_worker_query_mem_limit
    })
  ]
}

module "devserver" {
  count = var.devserver_enabled ? 1 : 0
  source = "./devserver"

  namespace = module.namespace.name

  image = var.image_devserver

  minio_secret_name = module.minio.secret_name
}
