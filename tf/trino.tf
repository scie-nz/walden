resource "random_password" "trino_admin_pass" {
  length = 32
  special = false
}

resource "kubernetes_secret" "trino_admin" {
  metadata {
    labels = {
      app = "trino"
    }
    name = "trino-admin"
    namespace = "walden"
  }
  type = "Opaque"
  data = {
    "pass" = random_password.trino_admin_pass.result
    "user" = "walden"
  }
}

resource "kubernetes_config_map" "trino_catalog" {
  metadata {
    name = "trino-catalog"
    namespace = "walden"
  }
  data = {
    "core-site.xml" = file("configs/trinocatalog_core-site.xml")

    "hive.properties" = templatefile(
      "configs/trinocatalog_hive.properties.template",
      {
        minio_access_key_id = sensitive(var.minio_username)
        minio_access_key_secret = var.minio_password == "" ? random_password.minio_admin_pass[0].result : var.minio_password,
      }
    )

    "jmx.properties" = <<-EOT
connector.name=jmx
EOT

    "tpch.properties" = <<-EOT
connector.name=tpch
EOT
  }
}

resource "kubernetes_config_map" "trino_config" {
  metadata {
    name = "trino-config"
    namespace = "walden"
  }
  data = {
    "config.properties" = templatefile(
      "configs/trino_config.properties.template",
      {
        query_max_memory_per_node = var.trino_config_query_max_memory_per_node,
        query_max_memory = var.trino_config_query_max_memory,
        memory_heap_headroom_per_node = var.trino_config_memory_heap_headroom_per_node,
        max_spill_per_node = var.trino_config_max_spill_per_node,
        query_max_spill_per_node = var.trino_config_query_max_spill_per_node,
      }
    )
    "jvm-coordinator.config" = templatefile(
      "configs/trino_jvm.config.template",
      {
        jvm_heap = var.trino_coordinator_mem_jvm_heap,
      }
    )
    "jvm-worker.config" = templatefile(
      "configs/trino_jvm.config.template",
      {
        jvm_heap = var.trino_worker_mem_jvm_heap,
      }
    )
    "log.properties" = file("configs/trino_log.properties")
    "node.properties" = file("configs/trino_node.properties")
    "password-authenticator.properties" = file("configs/trino_password-authenticator.properties")
    "password.db" = <<-EOT
walden:${bcrypt(random_password.trino_admin_pass.result)}
EOT
    "postgres.properties" = ""
  }
}

resource "kubernetes_service" "trino" {
  metadata {
    labels = {
      app = "trino-coordinator"
    }
    name = "trino"
    namespace = "walden"
  }
  spec {
    external_ips = var.trino_external_ips
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
    namespace = "walden"
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
mkdir -p /etc/trino/catalog &&
cp -v /tmp/roconf/* /etc/trino &&
cp -v /tmp/rocatalog*/* /etc/trino/catalog &&
mv -v /etc/trino/jvm-coordinator.config /etc/trino/jvm.config &&
export WORKER_NODE_ID="$${HOSTNAME}_$${RANDOM}" &&
/usr/lib/trino/bin/run-trino -v
EOT
          ]
          env {
            name = "CONFIG_COORDINATOR"
            value = "true"
          }
          env_from {
            # Custom environment variables to include in the trino nodes.
            # This may be used for customizing configuration, e.g. OIDC authentication.
            secret_ref {
              name = "trino-coordinator-env-extra"
              optional = true
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
            mount_path = "/tmp/roconf"
            name = "config"
          }
          volume_mount {
            mount_path = "/tmp/rocatalog"
            name = "catalog"
          }
          volume_mount {
            mount_path = "/tmp/rocatalog-extra"
            name = "catalog-extra"
          }
          volume_mount {
            mount_path = "/etc/trino"
            name = "etc"
          }
          volume_mount {
            mount_path = "/data/trino"
            name = "data"
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
            effect = toleration.effect
            key = toleration.key
            operator = toleration.operator
            value = toleration.value
          }
        }
        volume {
          config_map {
            name = "trino-config"
          }
          name = "config"
        }
        volume {
          config_map {
            name = "trino-catalog"
          }
          name = "catalog"
        }
        volume {
          config_map {
            name = "trino-catalog-extra"
            optional = true
          }
          name = "catalog-extra"
        }
        volume {
          empty_dir {}
          name = "etc"
        }
        volume {
          empty_dir {}
          name = "data"
        }
      }
    }
  }
}

# TODO(nick): deployment with emptyDir for alluxio-cache?
resource "kubernetes_stateful_set" "trino_worker" {
  metadata {
    labels = {
      app = "trino-worker"
    }
    name = "trino-worker"
    namespace = "walden"
  }
  spec {
    pod_management_policy = "Parallel"
    replicas = var.trino_worker_replicas
    selector {
      match_labels = {
        app = "trino-worker"
      }
    }
    service_name = "trino-worker"
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
mkdir -p /etc/trino/catalog &&
mkdir -p /diskcache/hive /memcache/hive &&
cp -v /tmp/roconf/* /etc/trino &&
cp -v /tmp/rocatalog*/* /etc/trino/catalog &&
mv -v /etc/trino/jvm-worker.config /etc/trino/jvm.config &&
export WORKER_NODE_ID="$${HOSTNAME}_$${RANDOM}" &&
${var.trino_worker_startup_command} &&
/usr/lib/trino/bin/run-trino -v
EOT
            ,
          ]
          env {
            name = "CONFIG_COORDINATOR"
            value = "false"
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
            mount_path = "/tmp/roconf"
            name = "trino-config"
          }
          volume_mount {
            mount_path = "/tmp/rocatalog"
            name = "trino-catalog"
          }
          volume_mount {
            mount_path = "/etc/trino"
            name = "trino-etc"
          }
          volume_mount {
            mount_path = "/memcache"
            name = "trino-memcache"
          }
          volume_mount {
            mount_path = "/diskcache"
            name = "trino-cache"
          }
          volume_mount {
            mount_path = "/data"
            name = "storage"
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
              value = "s3://alluxio/"
            }
            env {
              name = "AWS_ACCESS_KEY_ID"
              value_from {
                secret_key_ref {
                  key = "user"
                  name = "minio-admin"
                }
              }
            }
            env {
              name = "AWS_SECRET_ACCESS_KEY"
              value_from {
                secret_key_ref {
                  key = "pass"
                  name = "minio-admin"
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
            volume_mount {
              mount_path = "/mnt/cache"
              name = "alluxio-cache"
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
              value = "s3://alluxio/"
            }
            env {
              name = "AWS_ACCESS_KEY_ID"
              value_from {
                secret_key_ref {
                  key = "user"
                  name = "minio-admin"
                }
              }
            }
            env {
              name = "AWS_SECRET_ACCESS_KEY"
              value_from {
                secret_key_ref {
                  key = "pass"
                  name = "minio-admin"
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
            volume_mount {
              mount_path = "/mnt/cache"
              name = "alluxio-cache"
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
            effect = toleration.effect
            key = toleration.key
            operator = toleration.operator
            value = toleration.value
          }
        }
        volume {
          config_map {
            name = "trino-config"
          }
          name = "trino-config"
        }
        volume {
          config_map {
            name = "trino-catalog"
          }
          name = "trino-catalog"
        }
        volume {
          empty_dir {}
          name = "trino-etc"
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
              size_limit = "1Gi"
            }
            name = "alluxio-memcache"
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "storage"
      }
      spec {
        access_modes = [
          "ReadWriteOnce",
        ]
        resources {
          requests = {
            storage = var.trino_worker_disk_spill
          }
        }
      }
    }
    volume_claim_template {
      metadata {
        name = "trino-cache"
      }
      spec {
        access_modes = [
          "ReadWriteOnce",
        ]
        resources {
          requests = {
            storage = var.trino_worker_disk_cache
          }
        }
      }
    }
    dynamic "volume_claim_template" {
      for_each = var.alluxio_enabled ? ["_"] : []
      content {
        metadata {
          name = "alluxio-cache"
        }
        spec {
          access_modes = [
            "ReadWriteOnce",
          ]
          resources {
            requests = {
              storage = "10Gi"
            }
          }
        }
      }
    }
  }
}
