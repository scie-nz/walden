resource "kubernetes_config_map" "trino_catalog" {
  metadata {
    name = "trino-catalog"
    namespace = var.namespace
  }
  data = merge(
    var.trino_extra_catalogs,
    {
      "core-site.xml" = var.alluxio_enabled ? file("${path.module}/trinocatalog_core-site.xml") : ""

      "hive.properties" = templatefile(
        "${path.module}/trinocatalog_hive.properties.template",
        {
          alluxio_resource = var.alluxio_enabled ? "/etc/trino/catalog/core-site.xml" : ""
          metastore_host = var.metastore_host
          metastore_port = var.metastore_port
          minio_host = var.minio_host
          minio_port = var.minio_port
        }
      )

      "jmx.properties" = <<-EOT
connector.name=jmx
EOT

      "tpch.properties" = <<-EOT
connector.name=tpch
tpch.splits-per-node=4
EOT

      "tpcds.properties" = <<-EOT
connector.name=tpcds
tpcds.splits-per-node=4
EOT
    }
  )
}

resource "kubernetes_config_map" "trino_config" {
  metadata {
    name = "trino-config"
    namespace = var.namespace
  }
  data = {
    "config.properties" = templatefile(
      "${path.module}/trino_config.properties.template",
      {
        query_max_memory_per_node = var.trino_config_query_max_memory_per_node,
        query_max_memory = var.trino_config_query_max_memory,
        memory_heap_headroom_per_node = var.trino_config_memory_heap_headroom_per_node,
      }
    )

    "node.properties" = <<-EOT
node.environment=docker
node.data-dir=/data/trino

# To simplify debugging, let's include the podname/hostname directly.
# But randomness is also required to avoid the node.id staying the same across restarts/IP changes.
# This apparently confuses Trino's job scheduling where it tries to use the old IP even though it's
# not listed in SELECT * FROM system.runtime.nodes anymore
node.id=$${ENV:TRINO_NODE_ID}
EOT
  }
}

resource "kubernetes_service" "trino" {
  metadata {
    labels = {
      app = "trino-coordinator"
    }
    name = "trino"
    namespace = var.namespace
  }
  spec {
    port {
      name = "http"
      port = 80
      target_port = "http"
    }
    port {
      name = "hivecache-data"
      port = 8898
      target_port = "hivecache-data"
    }
    port {
      name = "hivecache-bk"
      port = 8899
      target_port = "hivecache-bk"
    }
    dynamic "port" {
      for_each = var.trino_extra_ports
      content {
        name = port.key
        port = port.value
        target_port = port.key
      }
    }
    selector = {
      app = "trino-coordinator"
    }
  }
}

resource "kubernetes_deployment" "trino_coordinator" {
  metadata {
    labels = {
      app = "trino-coordinator"
    }
    name = "trino-coordinator"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "trino-coordinator"
      }
    }
    template {
      metadata {
        labels = {
          app = "trino-coordinator"
        }
      }
      spec {
        container {
          command = [
            "/bin/bash",
            "-c",
            <<-EOT
export TRINO_NODE_ID="$${HOSTNAME}_$${RANDOM}" &&
/usr/lib/trino/bin/run-trino -v
EOT
          ]
          env {
            name = "CONFIG_COORDINATOR"
            value = "true"
          }
          env {
            name = "MINIO_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                key = "user"
                name = var.minio_secret_name
              }
            }
          }
          env {
            name = "MINIO_ACCESS_KEY_SECRET"
            value_from {
              secret_key_ref {
                key = "pass"
                name = var.minio_secret_name
              }
            }
          }
          image = var.image_trino
          liveness_probe {
            failure_threshold = 6
            initial_delay_seconds = 20
            period_seconds = 10
            http_get {
              path = "/v1/info"
              port = "http"
            }
            timeout_seconds = 5
          }
          name = "trino-coordinator"
          port {
            container_port = 8080
            name = "http"
          }
          port {
            container_port = 8898
            name = "hivecache-data"
          }
          port {
            container_port = 8899
            name = "hivecache-bk"
          }
          dynamic "port" {
            for_each = var.trino_extra_ports
            content {
              container_port = port.value
              name = port.key
            }
          }
          readiness_probe {
            failure_threshold = 6
            initial_delay_seconds = 20
            period_seconds = 10
            http_get {
              path = "/v1/info"
              port = "http"
            }
            timeout_seconds = 5
          }
          resources {
            limits = {
              memory = var.trino_coordinator_mem_limit
            }
          }
          volume_mount {
            mount_path = "/etc/trino/config.properties"
            name = "trino-config"
            sub_path = "config.properties"
          }
          volume_mount {
            mount_path = "/etc/trino/node.properties"
            name = "trino-config"
            sub_path = "node.properties"
          }
          volume_mount {
            mount_path = "/etc/trino/catalog"
            name = "trino-catalog"
          }
          volume_mount {
            mount_path = "/data/trino"
            name = "trino-data"
          }
        }
        node_selector = var.trino_coordinator_node_selector
        security_context {
          fs_group = 1000
          run_as_group = 1000
          run_as_user = 1000
        }
        dynamic "toleration" {
          for_each = var.trino_coordinator_tolerations
          content {
            effect = toleration.value.effect
            key = toleration.value.key
            operator = toleration.value.operator
            value = toleration.value.value
          }
        }
        volume {
          config_map {
            name = kubernetes_config_map.trino_config.metadata[0].name
          }
          name = "trino-config"
        }
        volume {
          config_map {
            name = kubernetes_config_map.trino_catalog.metadata[0].name
          }
          name = "trino-catalog"
        }
        volume {
          empty_dir {}
          name = "trino-data"
        }
      }
    }
  }
}

resource "kubernetes_deployment" "trino_worker" {
  metadata {
    labels = {
      app = "trino-worker"
    }
    name = "trino-worker"
    namespace = var.namespace
  }
  spec {
    replicas = var.trino_worker_replicas
    selector {
      match_labels = {
        app = "trino-worker"
      }
    }
    template {
      metadata {
        labels = {
          app = "trino-worker"
        }
      }
      spec {
        container {
          command = [
            "/bin/bash",
            "-c",
            <<-EOT
mkdir -p /memcache/hive &&
export TRINO_NODE_ID="$${HOSTNAME}_$${RANDOM}" &&
${var.trino_worker_startup_command} &&
/usr/lib/trino/bin/run-trino -v
EOT
          ]
          env {
            name = "CONFIG_COORDINATOR"
            value = "false"
          }
          env {
            name = "MINIO_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                key = "user"
                name = var.minio_secret_name
              }
            }
          }
          env {
            name = "MINIO_ACCESS_KEY_SECRET"
            value_from {
              secret_key_ref {
                key = "pass"
                name = var.minio_secret_name
              }
            }
          }
          image = var.image_trino
          liveness_probe {
            failure_threshold = 6
            initial_delay_seconds = 20
            period_seconds = 10
            http_get {
              path = "/v1/info"
              port = "http"
            }
            timeout_seconds = 5
          }
          name = "trino-worker"
          port {
            container_port = 8080
            name = "http"
          }
          port {
            container_port = 8898
            name = "hivecache-data"
          }
          port {
            container_port = 8899
            name = "hivecache-bk"
          }
          dynamic "port" {
            for_each = var.trino_extra_ports
            content {
              container_port = port.value
              name = port.key
            }
          }
          readiness_probe {
            failure_threshold = 6
            initial_delay_seconds = 20
            period_seconds = 10
            http_get {
              path = "/v1/info"
              port = "http"
            }
            timeout_seconds = 5
          }
          resources {
            limits = {
              memory = var.trino_worker_mem_limit
            }
          }
          volume_mount {
            mount_path = "/etc/trino/config.properties"
            name = "trino-config"
            sub_path = "config.properties"
          }
          volume_mount {
            mount_path = "/etc/trino/node.properties"
            name = "trino-config"
            sub_path = "node.properties"
          }
          volume_mount {
            mount_path = "/etc/trino/catalog"
            name = "trino-catalog"
          }
          volume_mount {
            mount_path = "/data/trino"
            name = "trino-data"
          }
          volume_mount {
            mount_path = "/memcache"
            name = "trino-memcache"
          }
          dynamic "volume_mount" {
            for_each = var.alluxio_enabled ? ["_"] : []
            content {
              mount_path = "/opt/domain"
              name = "alluxio-domain"
            }
          }
        }
        dynamic "container" {
          for_each = var.alluxio_enabled ? ["_"] : []
          content {
            args = [
              "worker-only",
              "--no-format",
            ]
            command = [
              "tini",
              "--",
              "/entrypoint.sh",
            ]
            env {
              name = "ALLUXIO_WORKER_HOSTNAME"
              value_from {
                field_ref {
                  field_path = "status.hostIP"
                }
              }
            }
            env {
              name = "ALLUXIO_WORKER_CONTAINER_HOSTNAME"
              value_from {
                field_ref {
                  field_path = "status.podIP"
                }
              }
            }
            env {
              name = "ALLUXIO_MASTER_MOUNT_TABLE_ROOT_UFS"
              value = var.alluxio_root_mount
            }
            env {
              name = "AWS_ACCESS_KEY_ID"
              value_from {
                secret_key_ref {
                  key = "user"
                  name = var.minio_secret_name
                }
              }
            }
            env {
              name = "AWS_SECRET_ACCESS_KEY"
              value_from {
                secret_key_ref {
                  key = "pass"
                  name = var.minio_secret_name
                }
              }
            }
            env_from {
              config_map_ref {
                name = "alluxio-config"
              }
            }
            image = var.image_alluxio
            liveness_probe {
              failure_threshold = 2
              initial_delay_seconds = 15
              period_seconds = 30
              tcp_socket {
                port = "alluxio-rpc"
              }
              timeout_seconds = 5
            }
            name = "alluxio-worker"
            port {
              container_port = 29999
              name = "alluxio-rpc"
            }
            port {
              container_port = 30000
              name = "alluxio-web"
            }
            readiness_probe {
              failure_threshold = 3
              initial_delay_seconds = 10
              period_seconds = 10
              success_threshold = 1
              tcp_socket {
                port = "alluxio-rpc"
              }
              timeout_seconds = 1
            }
            volume_mount {
              mount_path = "/opt/domain"
              name = "alluxio-domain"
            }
            volume_mount {
              mount_path = "/dev/shm"
              name = "alluxio-memcache"
            }
          }
        }
        dynamic "container" {
          for_each = var.alluxio_enabled ? ["_"] : []
          content {
            args = [
              "job-worker",
            ]
            command = [
              "tini",
              "--",
              "/entrypoint.sh",
            ]
            env {
              name = "ALLUXIO_WORKER_HOSTNAME"
              value_from {
                field_ref {
                  field_path = "status.hostIP"
                }
              }
            }
            env {
              name = "ALLUXIO_WORKER_CONTAINER_HOSTNAME"
              value_from {
                field_ref {
                  field_path = "status.podIP"
                }
              }
            }
            env {
              name = "ALLUXIO_MASTER_MOUNT_TABLE_ROOT_UFS"
              value = var.alluxio_root_mount
            }
            env {
              name = "AWS_ACCESS_KEY_ID"
              value_from {
                secret_key_ref {
                  key = "user"
                  name = var.minio_secret_name
                }
              }
            }
            env {
              name = "AWS_SECRET_ACCESS_KEY"
              value_from {
                secret_key_ref {
                  key = "pass"
                  name = var.minio_secret_name
                }
              }
            }
            env_from {
              config_map_ref {
                name = "alluxio-config"
              }
            }
            image = var.image_alluxio
            liveness_probe {
              failure_threshold = 2
              initial_delay_seconds = 15
              period_seconds = 30
              tcp_socket {
                port = "job-rpc"
              }
              timeout_seconds = 5
            }
            name = "alluxio-job"
            port {
              container_port = 30001
              name = "job-rpc"
            }
            port {
              container_port = 30002
              name = "job-data"
            }
            port {
              container_port = 30003
              name = "job-web"
            }
            readiness_probe {
              failure_threshold = 3
              initial_delay_seconds = 10
              period_seconds = 10
              success_threshold = 1
              tcp_socket {
                port = "job-rpc"
              }
              timeout_seconds = 1
            }
            volume_mount {
              mount_path = "/opt/domain"
              name = "alluxio-domain"
            }
            volume_mount {
              mount_path = "/dev/shm"
              name = "alluxio-memcache"
            }
          }
        }
        dynamic "init_container" {
          for_each = var.alluxio_enabled ? ["_"] : []
          content {
            command = [
              "/bin/sh",
              "-c",
              "until nc -zv $ALLUXIO_LEADER_HOST $ALLUXIO_LEADER_PORT -w1; do echo 'waiting for alluxio-leader'; sleep 1; done",
            ]
            env {
              name = "ALLUXIO_LEADER_HOST"
              value = "alluxio"
            }
            env {
              name = "ALLUXIO_LEADER_PORT"
              value = "19999"
            }
            image = var.image_busybox
            name = "wait-for-alluxio"
          }
        }
        node_selector = var.trino_worker_node_selector
        security_context {
          fs_group = 1000
          run_as_group = 1000
          run_as_user = 1000
        }
        termination_grace_period_seconds = 10
        dynamic "toleration" {
          for_each = var.trino_worker_tolerations
          content {
            effect = toleration.value.effect
            key = toleration.value.key
            operator = toleration.value.operator
            value = toleration.value.value
          }
        }
        volume {
          config_map {
            name = kubernetes_config_map.trino_config.metadata[0].name
          }
          name = "trino-config"
        }
        volume {
          config_map {
            name = kubernetes_config_map.trino_catalog.metadata[0].name
          }
          name = "trino-catalog"
        }
        volume {
          empty_dir {}
          name = "trino-data"
        }
        volume {
          empty_dir {
            medium = "Memory"
            size_limit = var.trino_worker_mem_cache
          }
          name = "trino-memcache"
        }
        dynamic "volume" {
          for_each = var.alluxio_enabled ? ["_"] : []
          content {
            empty_dir {}
            name = "alluxio-domain"
          }
        }
        dynamic "volume" {
          for_each = var.alluxio_enabled ? ["_"] : []
          content {
            empty_dir {
              medium = "Memory"
              size_limit = var.alluxio_mem_cache
            }
            name = "alluxio-memcache"
          }
        }
      }
    }
  }
}
