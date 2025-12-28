output "ekscn" {
  value = data.terraform_remote_state.eks.outputs.ekscn
}

output "eksca" {
  value = data.terraform_remote_state.eks.outputs.ekscca
}

output "ekscend" {
  value = data.terraform_remote_state.eks.outputs.ekscend
}

output "ip" {
    value = data.terraform_remote_state.eks.outputs.ip
}