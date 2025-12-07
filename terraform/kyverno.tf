locals {
    kypolicy = (templatefile("${path.module}/policies/kypolicy.yaml", {
}))
}

data "kubectl_file_documents" "kyp" {
  content = local.kypolicy
}

resource "kubectl_manifest" "kypolicy" {
  validate_schema = false #race error otherwise, could wait for the crds explicitly but it seems to work nonetheless
  for_each = data.kubectl_file_documents.kyp.manifests
  yaml_body = each.value

  depends_on = [
    helm_release.kyverno, aws_eks_cluster.eksc
  ]


}

data "aws_caller_identity" "me" {}

resource "helm_release" "kyverno" {
  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno"
  chart      = "kyverno"
  version    = "3.5.1"
  namespace  = "kyverno"
  create_namespace = true
  timeout = 600

  set = [

    {
      name = "global.image.registry",
      value = "${data.aws_caller_identity.me.account_id}.dkr.ecr.eu-central-1.amazonaws.com"
    },

    {
      name = "cleanupController.enabled", #check /caveats
      value = false
    },

    {
       name = "reportsController.enabled", #check /caveats
       value = false
    },

    {
       name = "admissionController.rbac.serviceAccount.name",
       value = "kyverno-admission-controller"
    },

    {
      name = "admissionController.rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn",
      value = aws_iam_role.kyverno.arn
    },

    {
      name = "backgroundController.rbac.serviceAccount.name",
      value = "kyverno-background-controller"
    },

    {
      name = "backgroundController.rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn",
      value = aws_iam_role.kyverno.arn
    },
    
    {
       name = "backgroundController.image.repository",
       value = "kyverno/background-controller"
    },

    {
      name = "admissionController.container.image.repository",
      value = "kyverno"
    },

    {
      name = "admissionController.initContainer.image.repository",
      value = "kyverno/kyvernopre"
    },

    {
      name = "admissionController.initContainer.image.tag",
      value = "v1.15.1"
    },

    {
      name = "admissionController.container.image.tag",
      value = "v1.15.1"
    },

    {
       name = "backgroundController.image.tag",
       value = "v1.15.1"
    }

  ]

  depends_on = [
    aws_eks_node_group.eksng
  ]

}

resource "aws_iam_role" "kyverno" {
  name = "kyverno"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eksc_oidc.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.path}:aud" = "sts.amazonaws.com"},
          StringLike = {
            "${local.path}:sub" = [
            "system:serviceaccount:kyverno:kyverno",
            "system:serviceaccount:kyverno:kyverno-admission-controller",
            "system:serviceaccount:kyverno:kyverno-background-controller",
            ]
          }
        }
    }]
  })
}

resource "aws_iam_role_policy" "kyvernop" {
    role = aws_iam_role.kyverno.name
    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchGetImage",
            "ecr:DescribeImages",
            "ecr:DescribeRepositories",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchCheckLayerAvailability",
            "ecr:ListImages"
          ],

          Resource = "*"
        }#,
        
       # {
       #   Effect = "Allow",
       #   Action = [
       #     "kms:GetPublicKey",      for dynamic KMS key fetching (check /caveats)
       #     "kms:DescribeKey"
       #   ],
       #   Resource = var.kms}
        ]
    })
}
