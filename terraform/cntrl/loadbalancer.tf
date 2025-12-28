
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
        Federated = data.terraform_remote_state.eks.outputs.ekscoidc
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

resource "helm_release" "lbc" {
  name = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart = "aws-load-balancer-controller"
  namespace = "kube-system"
  version = "1.13.4"
  wait = true

    set = [
      {name = "clusterName", value = data.terraform_remote_state.eks.outputs.ekscn},
      {name = "serviceAccount.create", value = "false"},
      {name = "serviceAccount.name", value = kubernetes_service_account.lbc.metadata[0].name},
      {name = "image.repository", value = "602401143452.dkr.ecr.eu-central-1.amazonaws.com/amazon/aws-load-balancer-controller"},
      {name = "enableWaf", value = "false"},
      {name = "enableWafv2", value = "false"},
      {name = "enableShield", value = "false"},
      {name = "vpcId", value = data.terraform_remote_state.eks.outputs.vpcid},
      {name = "region", value = "eu-central-1"},
    ]

    depends_on = [kubernetes_service_account.lbc,
    aws_iam_role_policy_attachment.lbcattachment, aws_iam_role.lbc, aws_iam_policy.AWSLoadBalancerControllerIAMPolicy]
}