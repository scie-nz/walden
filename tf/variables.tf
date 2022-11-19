# These are the default settings for starting a new Walden instance.
# To customize these options:
# 1. Make a copy of this file
# 2. Edit the copy
# 3. Deploy with "./deploy.sh <myvalues.yaml>"

variable "image_alluxio" {
  type = string
  description = "Stick with a server version matching the client library version in Trino"
  default = "docker.io/alluxio/alluxio:2.7.3"
}

variable "image_busybox" {
  type = string
  description = "Utility image for initContainers: config templating, waiting for dependencies to start."
  default = "docker.io/library/busybox:latest"
}

variable "image_minio" {
  type = string
  default = "docker.io/minio/minio:RELEASE.2022-05-08T23-50-31Z"
}

variable "image_postgres" {
  type = string
  description = "Changes to the Postgres major version require manually upgrading the on-disk data."
  default = "docker.io/library/postgres:14.1"
}

variable "image_redis" {
  type = string
  default = "docker.io/library/redis:7.0.0-bullseye"
}

# The latest release versions for Walden images.
# See walden/docker/* for image definitions.
variable "image_devserver" {
  type = string
  default = "docker.io/scienz/walden-devserver:2022.05.11"
}
variable "image_metastore" {
  type = string
  default = "docker.io/scienz/walden-metastore:2022.08.01"
}
variable "image_superset" {
  type = string
  default = "docker.io/scienz/walden-superset:2022.05.11"
}
variable "image_trino" {
  type = string
  default = "docker.io/scienz/walden-trino:2022.05.11b"
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
  default = true
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
variable "alluxio_disk_cache" {
  type = string
  default = "10G"
  description = "Disk storage for cache in each Alluxio/Trino worker. This can greatly speed up repeat access to data via Alluxio."
}
variable "alluxio_nfs_server" {
  type = string
  default = ""
  description = "Enabling an NFS volume mount (at /mnt/nfs) in the Alluxio pods. You can add the volume to Alluxio by either assigning root_mount above to /mnt/nfs, or via the alluxio CLI 'mount' command. Should be an IP or hostname, or empty to disable"
}
variable "alluxio_nfs_path" {
  type = string
  default = ""
  description = "a directory path, or empty to disable"
}
variable "alluxio_external_ips" {
  type = list(string)
  default = []
  description = "External IPs for the Alluxio service"
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
  validation {
    condition = var.minio_replicas >= 4
    error_message = "Minio requires a minimum of four replicas (minio_replicas)"
  }
}
variable "minio_arch" {
  type = string
  default = "amd64"
  description = "The CPU architecture for Minio nodes, all nodes must be running the same arch"
}
variable "minio_mem_limit" {
  type = string
  default = "512M"
  description = "The memory limit for each Minio pod. Minio recommends 8GB for pods with up to 1TB storage/pod, or 16GB for up to 10TB storage/pod. We start with very low values, increase to fit your system and workloads."
}
variable "minio_external_ips" {
  type = list(string)
  default = []
  description = "External IPs for the Minio service"
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
  default = "1G"
  description = "The memory limits for each the Superset worker pod. We start with very low values, increase to fit your system and workloads."
}
variable "superset_external_ips" {
  type = list(string)
  default = []
  description = "External IPs for the Superset service"
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
  description = "The memory limits for the Trino coordinator pod. We start with very low values, increase to fit your system and workloads. Note that Alluxio workers are colocated with Trino workers, so the sum total of alluxio_mem_cache and trino_mem_limit_worker must stay below total node memory."
}
variable "trino_coordinator_mem_jvm_heap" {
  type = string
  default = "1536M"
  description = "The value of '-Xmx' provided to the JVM in coordinators"
}
variable "trino_worker_mem_jvm_heap" {
  type = string
  default = "1536M"
  description = "The value of '-Xmx' provided to the JVM in workers"
}
variable "trino_worker_disk_spill" {
  type = string
  default = "25Gi"
  description = "Disk storage for 'spill' storage as configured below"
}
variable "trino_worker_disk_cache" {
  type = string
  default = "10Gi"
  description = "Disk storage for cache used for Hive catalogs in each Trino worker. This can greatly speed up repeat access to remote network volumes."
}
variable "trino_worker_mem_cache" {
  type = string
  default = "1Gi"
  description = "RAM storage for cache used for Hive catalogs in each Trino worker."
}
variable "trino_external_ips" {
  type = list(string)
  default = []
  description = "External IPs for the Trino UI service"
}

# Settings for trino_config.properties
# We start with very low values, increase to fit your system and workloads.
# Note: query.max-memory-per-node + memory.heap-headroom-per-node cannot be larger than mem_jvm_heap

variable "trino_config_query_max_memory_per_node" {
  type = string
  default = "1024MB"
  description = "query.max-memory-per-node (default: trino_mem_jvm_heap_worker * 0.3)"
}
variable "trino_config_query_max_memory" {
  type = string
  default = "4GB"
  description = "query.max-memory (default: 20GB)"
}
variable "trino_config_memory_heap_headroom_per_node" {
  type = string
  default = "512MB"
  description = "memory.heap-headroom-per-node (default: trino_mem_jvm_heap_worker * 0.3)"
}
variable "trino_config_max_spill_per_node" {
  type = string
  default = "25GB"
  description = "disk space, default: 100GB"
}
variable "trino_config_query_max_spill_per_node" {
  type = string
  default = "10GB"
}

variable "trino_worker_startup_command" {
  type = string
  default = "echo starting trino..."
  description = "A spot to insert custom commands/initialization before trino workers start"
}
variable "trino_extra_ports" {
  type = map
  default = {}
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
