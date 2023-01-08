# These are the default settings for starting a new Walden instance.
# To customize these options:
# 1. Create a 'terraform.tfvars'
# 2. Add rows to 'terraform.tfvars' for any overrides: varname = varvalue
# 3. Deploy with 'tf apply'

variable "image_alluxio" {
  type = string
  description = "Stick with a server version matching the client library version in Trino"
  # https://hub.docker.com/r/alluxio/alluxio/tags
  default = "docker.io/alluxio/alluxio:2.7.3"
}

variable "image_busybox" {
  type = string
  description = "Utility image for initContainers: config templating, waiting for dependencies to start."
  default = "docker.io/library/busybox:latest"
}

variable "image_minio" {
  type = string
  # https://hub.docker.com/r/minio/minio/tags
  default = "docker.io/minio/minio:RELEASE.2022-11-17T23-20-09Z"
}

variable "image_postgres" {
  type = string
  description = "Changes to the Postgres major version require manually upgrading the on-disk data."
  # https://hub.docker.com/r/_/postgres/tags
  default = "docker.io/library/postgres:15.1-bullseye"
}

variable "image_redis" {
  type = string
  # https://hub.docker.com/_/redis/tags
  default = "docker.io/library/redis:7.0.5-bullseye"
}

variable "image_trino" {
  type = string
  # https://hub.docker.com/r/trinodb/trino/tags
  default = "docker.io/trinodb/trino:403"
}

# The latest release versions for Walden images.
# See walden/docker/* for image definitions.
variable "image_devserver" {
  type = string
  default = "docker.io/scienz/walden-devserver:2023.01.08"
}
variable "image_metastore" {
  type = string
  default = "docker.io/scienz/walden-metastore:2022.08.01"
}
variable "image_superset" {
  type = string
  default = "docker.io/scienz/walden-superset:2023.01.08"
}

variable "namespace" {
  type = string
  default = "walden"
  description = "Kubernetes namespace where Walden should be deployed"
}

# DEVSERVER

variable "devserver_enabled" {
  type = bool
  default = true
  description = "Enables 'devserver' pod that's been preconfigured with access to Minio/Trino."
}

# ALLUXIO

variable "alluxio_enabled" {
  type = bool
  default = false
  description = "Enables Alluxio for additional managed data sources, along with caching of those sources. By default, Trino's Hive cache is often sufficient, but enabling Alluxio may be useful for supporting additional networked volume types that are not natively supported with Trino/Hive."
}
variable "alluxio_root_mount" {
  type = string
  default = "s3://alluxio/"
  description = "The root mount to be accessed by Alluxio. By default this is a Minio bucket named 'alluxio'. The 'alluxio' bucket must be created in Minio manually - see walden README for example. Alluxio is preconfigured with the Minio endpoint and credentials. Other options include an NFS mount, which can be enabled via the following option."
}
variable "alluxio_mem_cache" {
  type = string
  default = "1G"
  description = "The size of the ramdisk to use as cache in each Alluxio/Trino worker. This can greatly speed up repeat access to data via Alluxio. This is allocated as a ramdisk on startup, and is 'used' even if the workers are idle. Note that Alluxio workers are colocated with Trino workers, so the sum total of alluxio.mem_cache and trino.mem_limit_worker must stay below total node memory."
}

# MINIO

variable "minio_username" {
  type = string
  default = "walden"
  description = "The admin username for logging in to MinIO"
}
variable "minio_password" {
  type = string
  default = ""
  description = "The admin password for logging in to MinIO. If empty, a random value is generated and stored in the 'minio-admin' secret."
}
variable "minio_replicas" {
  type = number
  default = 4
  description = "The number of Minio replicas, must be at least four"
}
variable "minio_mem_limit" {
  type = string
  default = "512M"
  description = "The memory limit for each Minio pod. Minio recommends 8GB for pods with up to 1TB storage/pod, or 16GB for up to 10TB storage/pod. We start with very low values, increase to fit your system and workloads."
}
variable "minio_node_selector" {
  type = map
  default = {"kubernetes.io/arch" = "amd64"}
}
variable "minio_tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
  default = []
}

# SUPERSET

variable "superset_username" {
  type = string
  default = "walden"
  description = "The admin username for logging in to Superset. If empty, a random value is generated and stored in the 'superset-admin' secret. This only takes effect during initial install. If you want to change it later, edit the 'superset-admin' Secret directly and restart the Superset pod."
}
variable "superset_password" {
  type = string
  default = ""
  description = "The admin password for logging in to Superset. If empty, a random value is generated and stored in the 'superset-admin' secret. This only takes effect during initial install. If you want to change it later, edit the 'superset-admin' Secret directly and restart the Superset pod."
}
variable "superset_worker_replicas" {
  type = number
  default = 1
  description = "Number of celery worker replicas."
}
variable "superset_mem_limit_server" {
  type = string
  default = "512M"
  description = "The memory limits for each the Superset server pod. We start with very low values, increase to fit your system and workloads."
}
variable "superset_mem_limit_worker" {
  type = string
  default = "1Gi"
  description = "The memory limits for each the Superset worker pod. We start with very low values, increase to fit your system and workloads."
}

variable "superset_postgres_internal" {
  type = bool
  default = true
  description = "By default Walden will deploy a basic internal instance, but you may instead wish to provide your own. If internal=False, you must manually create a Secret named 'superset-postgres' containing external 'user'/'pass' credentials: 'kubectl create secret generic superset-postgres -n walden --from-literal=user=FOO --from-literal=pass=BAR'"
}
variable "superset_postgres_host" {
  type = string
  default = "superset-postgres"
  description = "Should only be customized if superset_postgres_internal is disabled"
}
variable "superset_postgres_port" {
  type = number
  default = 5432
  description = "Should only be customized if superset_postgres_internal is disabled"
}
variable "superset_postgres_db" {
  type = string
  default = "superset"
  description = "Should only be customized if superset_postgres_internal is disabled"
}
variable "superset_extra_datasources" {
  type = string
  default = ""
  description = "Extra YAML content for superset_datasources.yaml containing other data sources to be preconfigured"
}

variable "superset_scheduler_node_selector" {
  type = map
  default = {"kubernetes.io/arch" = "amd64"}
}
variable "superset_worker_node_selector" {
  type = map
  default = {"kubernetes.io/arch" = "amd64"}
}
variable "superset_app_node_selector" {
  type = map
  default = {"kubernetes.io/arch" = "amd64"}
}
variable "superset_scheduler_tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
  default = []
}
variable "superset_worker_tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
  default = []
}
variable "superset_app_tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
  default = []
}

# METASTORE

variable "metastore_postgres_internal" {
  type = bool
  default = true
  description = "By default Walden will deploy a basic internal instance, but you may instead wish to provide your own. If internal=False, you must manually create a Secret named 'metastore-postgres' containing external 'user'/'pass' credentials: 'kubectl create secret generic metastore-postgres -n walden --from-literal=user=FOO --from-literal=pass=BAR'"
}
variable "metastore_postgres_host" {
  type = string
  default = "metastore-postgres"
  description = "Should only be customized if metastore_postgres_internal is disabled"
}
variable "metastore_postgres_port" {
  type = number
  default = 5432
  description = "Should only be customized if metastore_postgres_internal is disabled"
}
variable "metastore_postgres_db" {
  type = string
  default = "metastore"
  description = "Should only be customized if metastore_postgres_internal is disabled"
}

# TRINO

variable "trino_coordinator_worker" {
  type = bool
  default = false
  description = "Whether the coordinator should also handle workloads. For a single-node deployment, this can be enabled with trino_worker_replicas set to 0"
}
variable "trino_worker_replicas" {
  type = number
  default = 1
  description = "Number of worker replicas. Each replica also gets an Alluxio worker, if Alluxio is enabled."
}
variable "trino_coordinator_mem_limit" {
  type = string
  default = "2Gi"
  description = "The memory limits for the Trino coordinator pod. We start with very low values, increase to fit your system and workloads."
}
variable "trino_worker_mem_limit" {
  type = string
  default = "2Gi"
  description = "The memory limits for the Trino coordinator pod. We start with very low values, increase to fit your system and workloads. Note that Alluxio workers are colocated with Trino workers, so the sum total of alluxio_mem_cache (if Alluxio is enabled) and trino_mem_limit_worker must stay below total node memory."
}
variable "trino_worker_mem_cache" {
  type = string
  default = "1Gi"
  description = "RAM storage for cache used for Hive catalogs in each Trino worker."
}
variable "trino_heap_mem_percent" {
  type = number
  default = 30
  description = "Percentage of mem_limit to allocate to heap. If this is too high then workers may be OOMKilled"
}

variable "trino_extra_command" {
  type = string
  default = "echo starting trino..."
  description = "A spot to insert custom startup commands before launching the trino process, in both the coordinator and the workers"
}
variable "trino_extra_ports" {
  type = map
  default = {}
  description = "Additional ports (name => number) for trino pods to listen on, for e.g. additional hive caches"
}
variable "trino_extra_catalogs" {
  type = map
  default = {}
  description = "Additional catalog files (filename => content) to provide to Trino"
}

variable "trino_coordinator_node_selector" {
  type = map
  default = {"kubernetes.io/arch" = "amd64"}
}
variable "trino_worker_node_selector" {
  type = map
  default = {"kubernetes.io/arch" = "amd64"}
}
variable "trino_coordinator_tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
  default = []
}
variable "trino_worker_tolerations" {
  type = list(object({
    effect = string
    key = string
    operator = string
    value = string
  }))
  default = []
}
