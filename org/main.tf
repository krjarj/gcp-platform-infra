resource "google_folder" "env" {
  for_each            = toset(["shared", "dev", "prod"])
  display_name        = each.key
  parent              = "organizations/${var.org_id}"
  deletion_protection = false # ny linje: så laben kan rives ned igen
}

# Ingen service account-nøgler i hele organisationen
resource "google_org_policy_policy" "no_sa_keys" {
  name   = "organizations/${var.org_id}/policies/iam.disableServiceAccountKeyCreation"
  parent = "organizations/${var.org_id}"
  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

# WIF-providers må kun pege på GitHub
resource "google_org_policy_policy" "wif_only_github" {
  name   = "organizations/${var.org_id}/policies/iam.workloadIdentityPoolProviders"
  parent = "organizations/${var.org_id}"
  spec {
    rules {
      values {
        allowed_values = ["https://token.actions.githubusercontent.com"]
      }
    }
  }
}