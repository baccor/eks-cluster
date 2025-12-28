data "terraform_remote_state" "main" {
  backend = "local"
  config = {
    path = "../main/terraform.tfstate"
  }
}