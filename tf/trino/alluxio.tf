resource "kubernetes_config_map" "alluxio" {
  count = var.alluxio_enabled ? 1 : 0
  metadata {
    labels = {
      app = "alluxio"
    }
    name = "alluxio-config"
    namespace = var.namespace
  }
  data = {
    "ALLUXIO_FUSE_JAVA_OPTS" = "-Dalluxio.user.hostname=$${ALLUXIO_CLIENT_HOSTNAME} -XX:MaxDirectMemorySize=2g"
    "ALLUXIO_JAVA_OPTS" = "-Dalluxio.master.hostname=alluxio -Dalluxio.master.journal.type=UFS -Dalluxio.master.journal.folder=/opt/alluxio/journal -Draft.server.storage.dir=/opt/alluxio/journal/JobJournal/raft -Dalluxio.security.stale.channel.purge.interval=365d -Dalluxio.master.mount.table.root.ufs=$${ALLUXIO_MASTER_MOUNT_TABLE_ROOT_UFS} -Dalluxio.master.mount.table.root.shared=true -Dalluxio.underfs.s3.endpoint=http://${var.minio_host}:${var.minio_port}/ -Dalluxio.underfs.s3.disable.dns.buckets=true -Dalluxio.underfs.s3.inherit.acl=false -Dalluxio.underfs.s3.default.mode=0777 -Dalluxio.security.login.username=alluxio -Dalluxio.security.authorization.permission.umask=000 -Dalluxio.user.file.writetype.default=CACHE_THROUGH -Dalluxio.user.file.persistence.initial.wait.time=5s -Dalluxio.user.file.persist.on.rename=true -Dalluxio.master.persistence.blacklist=hive-staging -Dalluxio.user.block.size.bytes.default=8MB"
    "ALLUXIO_JOB_MASTER_JAVA_OPTS" = "-Dalluxio.master.hostname=$${ALLUXIO_MASTER_HOSTNAME}"
    "ALLUXIO_JOB_WORKER_JAVA_OPTS" = "-Dalluxio.worker.hostname=$${ALLUXIO_WORKER_HOSTNAME} -Dalluxio.job.worker.rpc.port=30001 -Dalluxio.job.worker.data.port=30002 -Dalluxio.job.worker.web.port=30003"
    "ALLUXIO_MASTER_JAVA_OPTS" = "-Dalluxio.master.hostname=$${ALLUXIO_MASTER_HOSTNAME}"
    "ALLUXIO_WORKER_JAVA_OPTS" = "-Dalluxio.worker.hostname=$${ALLUXIO_WORKER_HOSTNAME} -Dalluxio.worker.rpc.port=29999 -Dalluxio.worker.web.port=30000 -Dalluxio.worker.data.server.domain.socket.address=/opt/domain -Dalluxio.worker.data.server.domain.socket.as.uuid=true -Dalluxio.worker.container.hostname=$${ALLUXIO_WORKER_CONTAINER_HOSTNAME} -Dalluxio.worker.ramdisk.size=${var.alluxio_mem_cache} -Dalluxio.worker.tieredstore.levels=1 -Dalluxio.worker.tieredstore.level0.alias=MEM -Dalluxio.worker.tieredstore.level0.dirs.path=/dev/shm"
    "ALLUXIO_WORKER_TIEREDSTORE_LEVEL0_DIRS_PATH" = "/dev/shm"
  }
}

resource "kubernetes_service" "alluxio_web" {
  count = var.alluxio_enabled ? 1 : 0
  metadata {
    labels = {
      app = "alluxio-leader"
    }
    name = "alluxio-web"
    namespace = var.namespace
  }
  spec {
    port {
      name = "web"
      port = 80
      target_port = "web"
    }
    selector = {
      app = "alluxio-leader"
    }
  }
}

resource "kubernetes_service" "alluxio" {
  count = var.alluxio_enabled ? 1 : 0
  metadata {
    labels = {
      app = "alluxio-leader"
    }
    name = "alluxio"
    namespace = var.namespace
  }
  spec {
    port {
      name = "rpc"
      port = 19998
      target_port = "rpc"
    }
    port {
      name = "web"
      port = 19999
      target_port = "web"
    }
    port {
      name = "job-rpc"
      port = 20001
      target_port = "job-rpc"
    }
    port {
      name = "job-web"
      port = 20002
      target_port = "job-web"
    }
    port {
      name = "embedded"
      port = 19200
    }
    port {
      name = "job-embedded"
      port = 20003
    }
    selector = {
      app = "alluxio-leader"
    }
  }
}

resource "kubernetes_stateful_set" "alluxio_leader" {
  count = var.alluxio_enabled ? 1 : 0
  metadata {
    labels = {
      app = "alluxio-leader"
    }
    name = "alluxio-leader"
    namespace = var.namespace
  }
  spec {
    pod_management_policy = "Parallel"
    replicas = 1
    selector {
      match_labels = {
        app = "alluxio-leader"
      }
    }
    service_name = "alluxio-leader"
    template {
      metadata {
        labels = {
          app = "alluxio-leader"
        }
      }
      spec {
        container {
          args = [
            "master-only",
            "--no-format",
          ]
          command = [
            "tini",
            "--",
            "/entrypoint.sh",
          ]
          env {
            name = "ALLUXIO_MASTER_HOSTNAME"
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
              port = "rpc"
            }
            timeout_seconds = 5
          }
          name = "leader"
          port {
            container_port = 19998
            name = "rpc"
          }
          port {
            container_port = 19999
            name = "web"
          }
          readiness_probe {
            failure_threshold = 3
            initial_delay_seconds = 10
            period_seconds = 10
            success_threshold = 1
            tcp_socket {
              port = "rpc"
            }
            timeout_seconds = 1
          }
          volume_mount {
            mount_path = "/opt/alluxio/journal"
            name = "storage"
          }
        }
        container {
          args = [
            "job-master",
          ]
          command = [
            "tini",
            "--",
            "/entrypoint.sh",
          ]
          env {
            name = "ALLUXIO_MASTER_HOSTNAME"
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
          name = "job-leader"
          port {
            container_port = 20001
            name = "job-rpc"
          }
          port {
            container_port = 20002
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
            mount_path = "/opt/alluxio/journal"
            name = "storage"
          }
        }
        init_container {
          command = [
            "alluxio",
            "formatJournal",
          ]
          env_from {
            config_map_ref {
              name = "alluxio-config"
            }
          }
          image = var.image_alluxio
          name = "journal-format"
          volume_mount {
            mount_path = "/opt/alluxio/journal"
            name = "storage"
          }
        }
        node_selector = {
          "kubernetes.io/arch" = "amd64"
        }
        security_context {
          fs_group = 1000
          run_as_group = 1000
          run_as_user = 1000
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
            storage = "1Gi"
          }
        }
      }
    }
  }
}
