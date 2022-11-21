resource "kubernetes_persistent_volume_claim" "devserver" {
  count = var.devserver_enabled ? 1 : 0
  metadata {
    name = "devserver"
    namespace = "walden"
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

resource "kubernetes_deployment" "devserver" {
  count = var.devserver_enabled ? 1 : 0
  metadata {
    name = "devserver"
    namespace = "walden"
  }
  spec {
    selector {
      match_labels = {
        app = "devserver"
      }
    }
    strategy {
      type = "Recreate"
    }
    template {
      metadata {
        labels = {
          app = "devserver"
        }
      }
      spec {
        container {
          command = [
            "/bin/bash",
            "-c",
            "cd ~ && sleep infinity",
          ]
          env {
            name = "MINIO_ACCESS_KEY_ID"
            value_from {
              secret_key_ref {
                key = "user"
                name = "minio-admin"
              }
            }
          }
          env {
            name = "MINIO_ACCESS_KEY_SECRET"
            value_from {
              secret_key_ref {
                key = "pass"
                name = "minio-admin"
              }
            }
          }
          env {
            name = "TRINO_USER"
            value_from {
              secret_key_ref {
                key = "user"
                name = "trino-admin"
              }
            }
          }
          env {
            name = "TRINO_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = "trino-admin"
              }
            }
          }
          env_from {
            # Custom environment variables to include in the devserver pod.
            secret_ref {
              name = "devserver-env-extra"
              optional = true
            }
          }
          image = var.image_devserver
          name = "devserver"
          resources {
            limits = {
              memory = "4096Mi"
            }
            requests = {
              memory = "2048Mi"
            }
          }
          volume_mount {
            mount_path = "/root"
            name = "devserver-persistent-storage"
          }
        }
        node_selector = {
          "kubernetes.io/arch" = "amd64"
        }
        volume {
          name = "devserver-persistent-storage"
          persistent_volume_claim {
            claim_name = "devserver"
          }
        }
      }
    }
  }
}
