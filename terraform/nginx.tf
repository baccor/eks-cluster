resource "kubernetes_deployment_v1" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.loadbalancer.metadata[0].name
  }

  spec {
    replicas = 2
    selector { match_labels = { app = "nginx" } }

    template {
      metadata { labels = { app = "nginx" } }
      spec {
        container {
          name  = "nginx"
          image = "${data.aws_caller_identity.me.account_id}.dkr.ecr.eu-central-1.amazonaws.com/images:import-nginx_stable-perl"
          port { container_port = 80 } 
        }
      }
    }
  }

  depends_on = [
    helm_release.kyverno
  ]
}


resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.loadbalancer.metadata[0].name
  }

  spec {
    selector = {
      app = "nginx"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment_v1.nginx, helm_release.lbc]
}
