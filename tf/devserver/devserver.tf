resource "kubernetes_persistent_volume_claim" "devserver" {
  metadata {
    name = "devserver"
    namespace = var.namespace
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
  metadata {
    name = "devserver"
    namespace = var.namespace
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
          image = var.image
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
