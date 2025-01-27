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

  set {
    name = "versionStoreType"
    value = "JDBC2"
  }
  set {
    name = "jdbc.jdbcUrl"
    value = var.nessie_postgres_internal ? "jdbc:postgresql://nessie-postgres:5432/nessie" : var.nessie_postgres_url
  }
  set {
    name = "jdbc.secret.name"
    value = var.nessie_postgres_internal ? "nessie-postgres" : ""
  }
  set {
    name = "jdbc.secret.username"
    value = "user"
  }
  set {
    name = "jdbc.secret.password"
    value = "pass"
  }
  # Object store settings.
  # This example uses MinIO as the object store.
  set {
    name = "catalog.iceberg.defaultWarehouse"
    value = "warehouse"
  }
  set {
    name = "catalog.iceberg.warehouses[0].location"
    value = "s3://demobucket/"
  }
  set {
    name = "catalog.storage.s3.defaultOptions.pathStyleAccess"
    value = "true"
  }
  set {
    name = "catalog.storage.s3.defaultOptions.accessKeySecret.name"
    value = "minio"
  }
  set {
    name = "catalog.storage.s3.defaultOptions.accessKeySecret.awsAccessKeyId"
    value = "user"
  }
  set {
    name = "catalog.storage.s3.defaultOptions.accessKeySecret.awsAccessKeyId"
    value = "pass"
  }
  # MinIO endpoint
  set {
    name = "catalog.storage.s3.defaultOptions.endpoint"
    value = "http://minio:9000/"
  }
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

  set {
    name = "server.workers"
    value = var.trino_worker_replicas
  }

  set {
    name = "coordinator.resources.limits.memory"
    value = var.trino_coordinator_mem_limit
  }
  set {
    name = "coordinator.resources.requests.memory"
    value = var.trino_coordinator_mem_limit
  }
  set {
    name = "coordinator.jvm.maxHeapSize"
    value = var.trino_coordinator_max_heap
  }
  set {
    name = "coordinator.config.query.maxMemoryPerNode"
    value = var.trino_coordinator_max_query_memory
  }

  set {
    name = "worker.resources.limits.memory"
    value = var.trino_worker_mem_limit
  }
  set {
    name = "worker.resources.requests.memory"
    value = var.trino_worker_mem_limit
  }
  set {
    name = "worker.jvm.maxHeapSize"
    value = var.trino_worker_max_heap
  }
  set {
    name = "worker.config.query.maxMemoryPerNode"
    value = var.trino_worker_max_query_memory
  }

  // TODO datatypes bad on these
  /*set {
    name = "catalogs"
    value = "{\"iceberg\":\"connector.name=iceberg-nessie\niceberg.catalog.type=nessie\niceberg.file-format=ORC\niceberg.nessie-catalog.uri=http://nessie:19120/api/v2\n\",\"tpcds\":\"connector.name=tpcds\ntpcds.splits-per-node=4\n\",\"tpch\":\"connector.name=tpch\ntpch.splits-per-node=4\n\"}"
  }
  set {
    name = "coordinator.nodeSelector"
    value = "${var.trino_coordinator_node_selector}"
  }
  set {
    name = "worker.nodeSelector"
    value = "${var.trino_worker_node_selector}"
  }*/
}

// TODO superset chart

module "devserver" {
  count = var.devserver_enabled ? 1 : 0
  source = "./devserver"

  namespace = module.namespace.name

  image = var.image_devserver

  minio_secret_name = module.minio.secret_name
}
