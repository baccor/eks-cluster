data "terraform_remote_state" "cntrl" {
  backend = "local"
  config = {
    path = "../cntrl/terraform.tfstate"
  }
}