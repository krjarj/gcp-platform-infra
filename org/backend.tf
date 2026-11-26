# org/backend.tf
terraform {
  backend "gcs" {
    bucket = "kjlab-tfstate"
    prefix = "org"
  }
}