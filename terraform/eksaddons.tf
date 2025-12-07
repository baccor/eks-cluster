resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.eksc.name
  addon_version = "v1.12.2-eksbuild.4"
  addon_name = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.eksng,
    aws_eks_addon.vpc_cni
  ]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.eksc.name
  addon_version               = "v1.20.1-eksbuild.3"
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  service_account_role_arn = aws_iam_role.cni_irsa.arn

}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name = aws_eks_cluster.eksc.name
  addon_version = "v1.33.3-eksbuild.4"
  addon_name = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
}
