project_id = "kjlab-dev"

subnets = {
  app       = { cidr = "10.10.0.0/24", region = "europe-north1" }
  analytics = { cidr = "10.10.1.0/24", region = "europe-north1" }
}