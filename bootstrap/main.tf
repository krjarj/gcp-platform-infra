locals {
  envs = toset(["dev", "prod"])

  seed_apis = [
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
  ]

  env_apis = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
  ]

  # Alle kombinationer af miljø og API, fx "dev-compute.googleapis.com"
  env_api_pairs = {
    for pair in setproduct(local.envs, local.env_apis) :
    "${pair[0]}-${pair[1]}" => { env = pair[0], api = pair[1] }
  }
}

# Slår de folders op, som org/ oprettede
data "google_active_folder" "this" {
  for_each     = toset(["shared", "dev", "prod"])
  display_name = each.key
  parent       = "organizations/${var.org_id}"
}

# ---------- Projekter ----------

resource "google_project" "seed" {
  project_id          = "${var.project_prefix}-seed"
  name                = "${var.project_prefix}-seed"
  folder_id           = trimprefix(data.google_active_folder.this["shared"].name, "folders/")
  billing_account     = var.billing_account
  deletion_policy     = "DELETE" # lab: må slettes med terraform destroy
  auto_create_network = false
}

resource "google_project" "env" {
  for_each            = local.envs
  project_id          = "${var.project_prefix}-${each.key}"
  name                = "${var.project_prefix}-${each.key}"
  folder_id           = trimprefix(data.google_active_folder.this[each.key].name, "folders/")
  billing_account     = var.billing_account
  deletion_policy     = "DELETE"
  auto_create_network = false
}

resource "google_project_service" "seed" {
  for_each           = toset(local.seed_apis)
  project            = google_project.seed.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_project_service" "env" {
  for_each           = local.env_api_pairs
  project            = google_project.env[each.value.env].project_id
  service            = each.value.api
  disable_on_destroy = false
}

# ---------- State-bucket ----------

resource "google_storage_bucket" "tfstate" {
  project                     = google_project.seed.project_id
  name                        = var.state_bucket_name
  location                    = upper(var.region)
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  # Behold de 10 seneste gamle versioner af hver state-fil
  lifecycle_rule {
    condition {
      num_newer_versions = 10
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.seed]
}

# ---------- Workload Identity Federation ----------

resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.seed.project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.seed]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = google_project.seed.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  attribute_condition = "assertion.repository_owner == '${var.github_owner}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ---------- Service accounts ----------

resource "google_service_account" "tf" {
  for_each     = local.envs
  project      = google_project.seed.project_id
  account_id   = "sa-terraform-${each.key}"
  display_name = "Terraform (GitHub Actions, ${each.key})"
  depends_on   = [google_project_service.seed]
}

# dev: alle jobs fra repoet (plan på PR og apply-dev)
resource "google_service_account_iam_member" "wif_dev" {
  service_account_id = google_service_account.tf["dev"].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${var.github_repo}"
}

# prod: kun jobs, der kører i GitHub-environmentet "prod"
resource "google_service_account_iam_member" "wif_prod" {
  service_account_id = google_service_account.tf["prod"].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/subject/repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:environment:prod"
}

# Hver service account får rettigheder i sit eget miljøprojekt
resource "google_project_iam_member" "tf_editor" {
  for_each = local.envs
  project  = google_project.env[each.key].project_id
  role     = "roles/editor" # lab: brug snævrere roller i produktion
  member   = "serviceAccount:${google_service_account.tf[each.key].email}"
}

# ... og må læse og skrive state
resource "google_storage_bucket_iam_member" "tf_state" {
  for_each = local.envs
  bucket   = google_storage_bucket.tfstate.name
  role     = "roles/storage.objectAdmin"
  member   = "serviceAccount:${google_service_account.tf[each.key].email}"
}