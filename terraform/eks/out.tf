output "ekscn" {
  value = aws_eks_cluster.eksc.name
}

output "ekscoidc" {
  value = aws_iam_openid_connect_provider.eksc_oidc.arn
}

output "ekscend" {
  value = data.aws_eks_cluster.eksc.endpoint
}

output "eksciss" {
    value = data.aws_eks_cluster.eksc.identity[0].oidc[0].issuer
}

output "vpcid" {
    value = data.terraform_remote_state.main.outputs.vpcid
}

output "ekscca" {
  value = base64decode(data.aws_eks_cluster.eksc.certificate_authority[0].data)
}

output "ip" {
    value = local.ip
}