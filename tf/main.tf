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

module "metastore" {
  source = "./metastore"

  namespace = kubernetes_namespace.walden.metadata[0].name
  name = "metastore"

  image_busybox = var.image_busybox
  image_metastore = var.image_metastore

  minio_host = "minio"
  minio_port = 9000
  minio_secret_name = "minio"

  postgres_host = var.metastore_postgres_host
  postgres_port = var.metastore_postgres_port
  postgres_db = var.metastore_postgres_db
  postgres_secret_name = "metastore-postgres"
}

module "metastore_postgres" {
  count = var.metastore_postgres_internal ? 1 : 0
  source = "./postgres"

  namespace = kubernetes_namespace.walden.metadata[0].name
  name = "metastore-postgres"
  image = var.image_postgres

  db = var.metastore_postgres_db
  storage = "1Gi"
}

module "minio" {
  source = "./minio"

  namespace = kubernetes_namespace.walden.metadata[0].name
  name = "minio"
  image = var.image_minio

  username = var.minio_username
  password = var.minio_password
  replicas = var.minio_replicas
  mem_limit = var.minio_mem_limit

  node_selector = var.minio_node_selector
  tolerations = var.minio_tolerations

  storage = "1Gi"
}

module "superset_postgres" {
  count = var.superset_postgres_internal ? 1 : 0
  source = "./postgres"

  namespace = kubernetes_namespace.walden.metadata[0].name
  name = "superset-postgres"
  image = var.image_postgres

  db = var.superset_postgres_db
  storage = "1Gi"
}

module "superset_redis" {
  source = "./redis"

  namespace = kubernetes_namespace.walden.metadata[0].name
  name = "superset-redis"
  image = var.image_redis

  max_memory = "100mb"
  storage = "1Gi"
}

module "superset" {
  source = "./superset"

  namespace = kubernetes_namespace.walden.metadata[0].name

  image_busybox = var.image_busybox
  image_superset = var.image_superset

  username = var.superset_username
  password = var.superset_password
  worker_replicas = var.superset_worker_replicas
  mem_limit_server = var.superset_mem_limit_server
  mem_limit_worker = var.superset_mem_limit_worker

  postgres_host = var.superset_postgres_host
  postgres_port = var.superset_postgres_port
  postgres_db = var.superset_postgres_db
  postgres_secret_name = "superset-postgres"

  redis_host = "superset-redis"
  redis_secret_name = "superset-redis"

  extra_datasources = var.superset_extra_datasources

  scheduler_node_selector = var.superset_scheduler_node_selector
  worker_node_selector = var.superset_worker_node_selector
  app_node_selector = var.superset_app_node_selector

  scheduler_tolerations = var.superset_scheduler_tolerations
  worker_tolerations = var.superset_worker_tolerations
  app_tolerations = var.superset_app_tolerations
}

module "trino" {
  source = "./trino"

  namespace = kubernetes_namespace.walden.metadata[0].name

  image_alluxio = var.image_alluxio
  image_busybox = var.image_busybox
  image_trino = var.image_trino

  metastore_host = "metastore"
  metastore_port = 9083

  minio_host = "minio"
  minio_port = 9000
  minio_secret_name = "minio"

  alluxio_enabled = var.alluxio_enabled
  alluxio_root_mount = var.alluxio_root_mount
  alluxio_mem_cache = var.alluxio_mem_cache

  trino_worker_replicas = var.trino_worker_replicas
  trino_coordinator_mem_limit = var.trino_coordinator_mem_limit
  trino_worker_mem_limit = var.trino_worker_mem_limit
  trino_worker_mem_cache = var.trino_worker_mem_cache

  trino_config_query_max_memory_per_node = var.trino_config_query_max_memory_per_node
  trino_config_query_max_memory = var.trino_config_query_max_memory
  trino_config_memory_heap_headroom_per_node = var.trino_config_memory_heap_headroom_per_node

  trino_worker_startup_command = var.trino_worker_startup_command
  trino_extra_ports = var.trino_extra_ports
  trino_extra_catalogs = var.trino_extra_catalogs

  trino_coordinator_node_selector = var.trino_coordinator_node_selector
  trino_worker_node_selector = var.trino_worker_node_selector
  trino_coordinator_tolerations = var.trino_coordinator_tolerations
  trino_worker_tolerations = var.trino_worker_tolerations
}

module "devserver" {
  count = var.devserver_enabled ? 1 : 0
  source = "./devserver"

  namespace = kubernetes_namespace.walden.metadata[0].name

  image = var.image_devserver

  minio_secret_name = "minio"
}
