variable "org_id" {
  type = string
}

variable "billing_account" {
  type        = string
  description = "Billing-kontoens ID, fx XXXXXX-XXXXXX-XXXXXX"
}

variable "project_prefix" {
  type    = string
  default = "kjlab"
}

variable "state_bucket_name" {
  type    = string
  default = "kjlab-tfstate"
}

variable "region" {
  type    = string
  default = "europe-north1"
}

variable "github_owner" {
  type    = string
  default = "krjarj"
}

variable "github_repo" {
  type    = string
  default = "gcp-platform-infra"
}

# Uforanderlige ID'er, som GitHub skriver i tokenets sub-claim
variable "github_owner_id" {
  type    = string
  default = "267884076"
}

variable "github_repo_id" {
  type    = string
  default = "1471662267"
}