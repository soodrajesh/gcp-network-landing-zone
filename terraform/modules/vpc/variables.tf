variable "project_id" { type = string }
variable "region" { type = string }
variable "zone" { type = string }

variable "name" {
  description = "hub | prod | dev"
  type        = string
}

variable "cidr" { type = string }

variable "allowed_sources" {
  description = "CIDRs allowed to reach the workload port. Everything else is denied and logged."
  type        = list(string)
}

variable "workload_port" {
  type    = string
  default = "8080"
}
