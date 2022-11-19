resource "kubernetes_config_map" "metastore" {
  metadata {
    labels = {
      app = "metastore"
    }
    name = "metastore"
    namespace = "walden"
  }
  data = {
    "metastore-site.xml.template" = templatefile(
      "configs/metastore-site.xml.template",
      {
        postgres_host = var.metastore_postgres_host,
        postgres_port = var.metastore_postgres_port,
        postgres_db = var.metastore_postgres_db,
      }
    )
  }
}

resource "kubernetes_service" "metastore" {
  metadata {
    labels = {
      app = "metastore"
    }
    name = "metastore"
    namespace = "walden"
  }
  spec {
    port {
      name = "metastore"
      port = 9083
      target_port = "metastore"
    }
    selector = {
      app = "metastore"
    }
  }
}

resource "kubernetes_deployment" "metastore" {
  metadata {
    labels = {
      app = "metastore"
    }
    name = "metastore"
    namespace = "walden"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "metastore"
      }
    }
    template {
      metadata {
        labels = {
          app = "metastore"
        }
      }
      spec {
        container {
          command = [
            "/bin/bash",
            "-c",
            <<-EOT
bash -c "echo -e \"$(cat /config/metastore-site.xml.template)\" > /opt/hive-metastore/conf/metastore-site.xml" &&
/opt/hive-metastore/bin/schematool -initSchema -dbType postgres -ifNotExists &&
/opt/hive-metastore/bin/start-metastore
EOT
            ,
          ]
          env {
            name = "METASTORE_PORT"
            value = "9083"
          }
          # use whatever user/pw is provided by the secret: user provides this when !metastore_postgres_internal
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                key = "user"
                name = "metastore-postgres"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                key = "pass"
                name = "metastore-postgres"
              }
            }
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
            name = "AWS_SECRET_KEY"
            value_from {
              secret_key_ref {
                key = "pass"
                name = "minio-admin"
              }
            }
          }
          image = var.image_metastore
          name = "metastore"
          port {
            container_port = 9083
            name = "metastore"
          }
          volume_mount {
            # Avoid collision with /opt/hive-metastore/conf/metastore-log4j2.properties
            mount_path = "/config"
            name = "config"
          }
        }
        init_container {
          command = [
            "/bin/sh",
            "-c",
            "until nc -zv $POSTGRES_HOST $POSTGRES_PORT -w1; do echo waiting for postgres: $${POSTGRES_HOST}:$${POSTGRES_PORT}; sleep 1; done",
          ]
          env {
            name = "POSTGRES_HOST"
            value = var.metastore_postgres_host
          }
          env {
            name = "POSTGRES_PORT"
            value = var.metastore_postgres_port
          }
          image = var.image_busybox
          name = "wait-for-postgres"
        }
        node_selector = {
          "kubernetes.io/arch" = "amd64"
        }
        restart_policy = "Always"
        volume {
          config_map {
            name = "metastore"
          }
          name = "config"
        }
      }
    }
  }
}
