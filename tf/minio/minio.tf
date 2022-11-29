resource "random_password" "admin_pass" {
  count = var.password == "" ? 1 : 0
  length = 32
  special = false
}

resource "kubernetes_secret" "minio" {
  metadata {
    labels = {
      app = var.name
    }
    name = var.name
    namespace = var.namespace
  }
  type = "Opaque"
  data = {
    pass = var.password == "" ? random_password.admin_pass[0].result : var.password
    user = sensitive(var.username)
  }
}

resource "kubernetes_service" "minio" {
  metadata {
    labels = {
      app = var.name
    }
    name = var.name
    namespace = var.namespace
  }
  spec {
    port {
      name = "s3"
      port = 9000
      target_port = "s3"
    }
    port {
      name = "console"
      port = 8080
      target_port = "console"
    }
    selector = {
      app = var.name
    }
  }
}

resource "kubernetes_service" "minio_headless" {
  metadata {
    labels = {
      app = var.name
    }
    name = "${var.name}-headless"
    namespace = var.namespace
  }
  spec {
    cluster_ip = "None"
    port {
      name = "s3"
      port = 9000
      target_port = "s3"
    }
    selector = {
      app = var.name
    }
  }
}

resource "kubernetes_stateful_set" "minio" {
  metadata {
    labels = {
      app = var.name
    }
    name = var.name
    namespace = var.namespace
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = var.name
      }
    }
    service_name = "${var.name}-headless"
    template {
      metadata {
        labels = {
          app = var.name
        }
      }
      spec {
        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key = "app"
                  operator = "In"
                  values = [
                    var.name,
                  ]
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }
        container {
          command = [
            "/bin/bash",
            "-c",
            "minio server --console-address :8080 http://${var.name}-{0...${var.replicas - 1}}.${var.name}-headless.${var.namespace}.svc.cluster.local:9000/data",
          ]
          env {
            name = "MINIO_ROOT_USER"
            value_from {
              secret_key_ref {
                key = "user"
                name = kubernetes_secret.minio.metadata[0].name
              }
            }
          }
          env {
            name = "MINIO_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = kubernetes_secret.minio.metadata[0].name
              }
            }
          }
          env {
            name = "MINIO_UPDATE"
            value = "off"
          }
          image = var.image
          name = "minio"
          port {
            container_port = 9000
            name = "s3"
          }
          port {
            container_port = 8080
            name = "console"
          }
          resources {
            limits = {
              memory = var.mem_limit
            }
          }
          volume_mount {
            mount_path = "/data"
            name = "storage"
          }
        }
        node_selector = var.node_selector
        dynamic "toleration" {
          for_each = var.tolerations
          content {
            effect = toleration.value.effect
            key = toleration.value.key
            operator = toleration.value.operator
            value = toleration.value.value
          }
        }
        security_context {
          fs_group = 65534
          run_as_group = 65534
          run_as_user = 65534
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
            storage = var.storage
          }
        }
      }
    }
  }
}
