variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-north1"
}

variable "subnets" {
  type = map(object({
    cidr   = string
    region = string
  }))
}
