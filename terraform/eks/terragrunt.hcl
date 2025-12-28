include "main" {
  path = find_in_parent_folders()
}

dependency "main" {
  config_path = "../main"
}
