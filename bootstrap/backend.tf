terraform {
  backend "gcs" {
    bucket = "kjlab-tfstate"
    prefix = "bootstrap"
  }
}
