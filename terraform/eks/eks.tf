terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
      version = "2.1.3"
    }
    http = {source = "hashicorp/http"}
  }
}

locals {
  vpcid = data.terraform_remote_state.main.outputs.vpcid
  prs1 = data.terraform_remote_state.main.outputs.prs1
  prs2 = data.terraform_remote_state.main.outputs.prs2
  path = replace(data.aws_eks_cluster.eksc.identity[0].oidc[0].issuer, "https://", "")
  ipc = chomp(data.http.ip.response_body)
  ip = "${local.ipc}/32"
  prrtid = data.terraform_remote_state.main.outputs.prrtid
  vpnsgid = data.terraform_remote_state.main.outputs.vpnsgid
}


provider "kubernetes" {
  host                   = data.aws_eks_cluster.eksc.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eksc.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name", aws_eks_cluster.eksc.name,
      "--region", "eu-central-1",
    ]
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.eksc.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eksc.certificate_authority[0].data)

    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name", aws_eks_cluster.eksc.name,
        "--region", "eu-central-1",
      ]
    }
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.eksc.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eksc.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name", aws_eks_cluster.eksc.name,
      "--region", "eu-central-1",
    ]
  }
}

data "tls_certificate" "oidc" {
  url = data.aws_eks_cluster.eksc.identity[0].oidc[0].issuer
}

data "http" "ip" {
  url = "https://checkip.amazonaws.com"
}

resource "aws_iam_openid_connect_provider" "eksc_oidc" {
  url             = data.aws_eks_cluster.eksc.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "cni_irsa" {
  name = "cni_irsa"
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
          "${local.path}:aud" = "sts.amazonaws.com",
          "${local.path}:sub" = "system:serviceaccount:kube-system:aws-node"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cnia" {
  role       = aws_iam_role.cni_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

data "aws_eks_cluster" "eksc" {
  name = aws_eks_cluster.eksc.name
}

resource "aws_iam_role" "ekscr" {
  name = "ekscr"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ekscpa" {
  role       = aws_iam_role.ekscr.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


resource "aws_iam_role" "eksnr" {
  name = "eksnr"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eksnwnp" {
  role       = aws_iam_role.eksnr.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eksncrr" {
  role       = aws_iam_role.eksnr.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_vpc_security_group_ingress_rule" "vpning" {
 security_group_id = aws_eks_cluster.eksc.vpc_config[0].cluster_security_group_id
 referenced_security_group_id = local.vpnsgid

 from_port   = 443
 ip_protocol = "tcp"
 to_port     = 443
}


resource "aws_eks_cluster" "eksc" {
  name     = "eksc"
  role_arn = aws_iam_role.ekscr.arn
  vpc_config {
    subnet_ids = [
      local.prs1,
      local.prs2
    ]
    endpoint_public_access  = false
    endpoint_private_access = true
  }
}

resource "aws_eks_node_group" "eksng" {
  cluster_name    = aws_eks_cluster.eksc.name
  node_group_name = "eksng"
  node_role_arn   = aws_iam_role.eksnr.arn
  instance_types  = ["t2.micro"]
  disk_size       = 20
  ami_type        = "AL2023_x86_64_STANDARD"
  capacity_type   = "ON_DEMAND"



  subnet_ids = [
    local.prs1,
    local.prs2
  ] 
  scaling_config {
    desired_size = 7
    max_size     = 7
    min_size     = 7
  }

}

resource "aws_security_group" "vpce" {
  name   = "vpce"
  vpc_id = local.vpcid
}


resource "aws_vpc_security_group_ingress_rule" "ngen" {
  from_port                = 443
  to_port                  = 443
  ip_protocol              = "tcp"
  security_group_id        = aws_security_group.vpce.id
  referenced_security_group_id = aws_eks_cluster.eksc.vpc_config[0].cluster_security_group_id
}


