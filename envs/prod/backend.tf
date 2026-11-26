terraform {
  backend "gcs" {
    bucket = "kjlab-tfstate"
    prefix = "envs/prod"
  }
}
