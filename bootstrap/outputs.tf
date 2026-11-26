output "wif_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "service_accounts" {
  value = { for env, sa in google_service_account.tf : env => sa.email }
}

output "projects" {
  value = { for env, p in google_project.env : env => p.project_id }
}

output "state_bucket" {
  value = google_storage_bucket.tfstate.name
}