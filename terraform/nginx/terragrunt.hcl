include "main" {
  path = find_in_parent_folders()
}

dependency "cntrl" {
  config_path = "../cntrl"
}
