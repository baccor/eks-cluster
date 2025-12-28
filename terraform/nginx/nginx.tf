provider "kubernetes" {
  host                   = data.terraform_remote_state.cntrl.outputs.ekscend
  cluster_ca_certificate = data.terraform_remote_state.cntrl.outputs.eksca

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name", data.terraform_remote_state.cntrl.outputs.ekscn,
      "--region", "eu-central-1",
    ]
  }
}

data "aws_caller_identity" "me" {}

resource "kubernetes_ingress_v1" "lb" {
  metadata {
    name = "lb"
    namespace = "loadbalancer"
    annotations = {
      "kubernetes.io/ingress.class" = "alb"
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\":80}]"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/"
      "alb.ingress.kubernetes.io/inbound-cidrs" = data.terraform_remote_state.cntrl.outputs.ip
      "alb.ingress.kubernetes.io/load-balancer-name"= "nginxlb"
    }
  }
  spec {
    rule {
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "nginx"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.nginx]

} 

resource "aws_wafv2_ip_set" "waf" {
  name = "waf"
  scope = "REGIONAL"
  ip_address_version = "IPV4"
  addresses = [data.terraform_remote_state.cntrl.outputs.ip]
}

resource "aws_wafv2_web_acl" "waf" {
  name = "waf"
  scope = "REGIONAL"

  default_action {
    block {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name = "waf"
    sampled_requests_enabled = false
  }

  rule {
    name = "rl"
    priority = 1

    action {
      block {}
    }
    
    statement{
    rate_based_statement {
      limit = 50
      aggregate_key_type = "IP"
      scope_down_statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.waf.arn
        }
      }
    }
    }
    
    

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name = "rl"
      sampled_requests_enabled = false
    }
  }

  rule {
    name = "ips"
    priority = 2

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.waf.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name = "rl"
      sampled_requests_enabled = false
    }
  }

  depends_on = [
    aws_wafv2_ip_set.waf
  ]

}

resource "null_resource" "lbw" { #otherwise the data right below throws an error and acl association needs an arn that is not yet existent so it just needs to wait
  provisioner "local-exec" {
    command = <<EOT
for i in $(seq 1 60); do
  aws elbv2 describe-load-balancers --names nginxlb --region eu-central-1 >/dev/null 2>&1 && exit 0 
  sleep 10
done
exit 1
EOT
  }

  depends_on = [kubernetes_ingress_v1.lb]
}

data "aws_lb" "lb" {
  name = "nginxlb"
  depends_on = [
    null_resource.lbw
  ]
}

resource "aws_wafv2_web_acl_association" "wafa" {
  resource_arn = data.aws_lb.lb.arn
  web_acl_arn = aws_wafv2_web_acl.waf.arn

  depends_on = [
    kubernetes_ingress_v1.lb,
    data.aws_lb.lb
  ]

}

resource "kubernetes_deployment_v1" "nginx" {
  metadata {
    name      = "nginx"
    namespace = "loadbalancer"
  }

  spec {
    replicas = 2
    selector { match_labels = { app = "nginx" } }

    template {
      metadata { labels = { app = "nginx" } }
      spec {
        container {
          name  = "nginx"
          image = "${data.aws_caller_identity.me.account_id}.dkr.ecr.eu-central-1.amazonaws.com/images:import-nginx_perl"
          port { container_port = 80 } 
        }
      }
    }
  }
}


resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx"
    namespace = "loadbalancer"
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

  depends_on = [kubernetes_deployment_v1.nginx]
}



