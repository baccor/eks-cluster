terraform {
  required_providers {
    kubectl = {
      source = "alekc/kubectl"
      version = "2.1.3"
    }
    http = {source = "hashicorp/http"}
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.ekscend
  cluster_ca_certificate = data.terraform_remote_state.eks.outputs.ekscca

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name", data.terraform_remote_state.eks.outputs.ekscn,
      "--region", "eu-central-1",
    ]
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.eks.outputs.ekscend
    cluster_ca_certificate = data.terraform_remote_state.eks.outputs.ekscca

    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name", data.terraform_remote_state.eks.outputs.ekscn,
        "--region", "eu-central-1",
      ]
    }
  }
}

provider "kubectl" {
  host                   = data.terraform_remote_state.eks.outputs.ekscend
  cluster_ca_certificate = data.terraform_remote_state.eks.outputs.ekscca

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name", data.terraform_remote_state.eks.outputs.ekscn,
      "--region", "eu-central-1",
    ]
  }
}