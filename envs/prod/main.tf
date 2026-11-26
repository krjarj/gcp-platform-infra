resource "google_compute_network" "vpc" {
  name                    = "vpc-main"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "this" {
  for_each                 = var.subnets
  name                     = each.key
  ip_cidr_range            = each.value.cidr
  region                   = each.value.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true
}
