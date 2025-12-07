resource "kubernetes_namespace" "loadbalancer" {
  metadata {
    name = "loadbalancer"
  }
}

resource aws_iam_policy "AWSLoadBalancerControllerIAMPolicy" {
  name = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/policies/iam-policy.json")
}

resource "aws_iam_role" "lbc" {
  name = "aws-load-balancer-controller-irsa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eksc_oidc.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.path}:aud" = "sts.amazonaws.com",
          "${local.path}:sub" = "system:serviceaccount:kube-system:lbc"
      } }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lbcattachment" {
  policy_arn = aws_iam_policy.AWSLoadBalancerControllerIAMPolicy.arn
  role      = aws_iam_role.lbc.name
}

resource "kubernetes_service_account" "lbc" {
  metadata {
    name = "lbc"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lbc.arn
    }
  }
}

resource "kubernetes_ingress_v1" "lb" {
  metadata {
    name = "lb"
    namespace = kubernetes_namespace.loadbalancer.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\":80}]"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/"
      "alb.ingress.kubernetes.io/inbound-cidrs" = local.ip
      "alb.ingress.kubernetes.io/load-balancer-name"= "nginxlb"
    }
  }
  spec {
ingress_class_name = "alb"
    rule {
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.lbc, kubernetes_service.nginx
  ]
} 

resource "helm_release" "lbc" {
  name = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart = "aws-load-balancer-controller"
  namespace = "kube-system"
  version = "1.13.4"
  wait = true
  timeout = 600

    set = [
      {name = "clusterName", value = aws_eks_cluster.eksc.name},
      {name = "serviceAccount.create", value = "false"},
      {name = "serviceAccount.name", value = kubernetes_service_account.lbc.metadata[0].name},
      {name = "image.repository", value = "602401143452.dkr.ecr.eu-central-1.amazonaws.com/amazon/aws-load-balancer-controller"},
      {name = "enableWaf", value = "false"},
      {name = "enableWafv2", value = "false"},
      {name = "enableShield", value = "false"},
      {name = "vpcId", value = aws_vpc.vpc.id},
      {name = "region", value = "eu-central-1"},
    ]

  depends_on = [
    kubernetes_service_account.lbc,
    aws_eks_node_group.eksng,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.coredns,
  ]
}

resource "aws_wafv2_ip_set" "waf" {
  name = "waf"
  scope = "REGIONAL"
  ip_address_version = "IPV4"
  addresses = [local.ip]
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
    helm_release.lbc,
    kubernetes_ingress_v1.lb

  ]
}
