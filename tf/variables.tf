# These are the default settings for starting a new Walden instance.
# To customize these options:
# 1. Create a 'terraform.tfvars'
# 2. Add rows to 'terraform.tfvars' for any overrides: varname = varvalue
# 3. Deploy with 'tf apply'

variable "image_busybox" {
  type = string
  description = "Utility image for initContainers: config templating, waiting for dependencies to start."
  default = "docker.io/library/busybox:latest"
}

variable "image_minio" {
  type = string
  # https://hub.docker.com/r/minio/minio/tags
  default = "docker.io/minio/minio:RELEASE.2025-01-20T14-49-07Z"
}

variable "image_postgres" {
  type = string
  description = "Changes to the Postgres major version require manually upgrading the on-disk data."
  # https://hub.docker.com/_/postgres/tags
  default = "docker.io/library/postgres:17.2-bookworm"
}

variable "image_redis" {
  type = string
  # https://hub.docker.com/_/redis/tags
  # Sticking with the final BSD-licensed version
  default = "docker.io/library/redis:7.2.4-bookworm"
}

variable "image_trino" {
  type = string
  # https://hub.docker.com/r/trinodb/trino/tags
  default = "docker.io/trinodb/trino:468"
}

# The latest release versions for Walden images.
# See walden/docker/* for image definitions.
variable "image_devserver" {
  type = string
  default = "ghcr.io/scie-nz/walden:devserver-2023.01.08"
}
# In theory there's a 4.0.1 release of standalone metastore, but it's just got a src tgz.
# So we stick with 3.1.3 from 2022 for now. A future version of Walden might replace metastore anyway.
variable "image_metastore" {
  type = string
  default = "ghcr.io/scie-nz/walden:metastore-2022.08.01"
}
variable "image_superset" {
  type = string
  default = "ghcr.io/scie-nz/walden:superset-2023.01.08"
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
  description = "Number of Trino worker instances"
}
variable "trino_coordinator_mem_limit" {
  type = string
  default = "2Gi"
  description = "The memory limits for the Trino coordinator pod. We start with very low values, increase to fit your system and workloads."
}
variable "trino_worker_mem_limit" {
  type = string
  default = "2Gi"
  description = "The memory limits for the Trino coordinator pod. We start with very low values, increase to fit your system and workloads."
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
