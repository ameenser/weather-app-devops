terraform {
  backend "s3" {
    bucket       = "ameen-weather-app-terraform-state-619605943762-us-east-1"
    key          = "persistent-storage/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
