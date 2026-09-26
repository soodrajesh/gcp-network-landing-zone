variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "billing_account_id" {
  type = string
}

variable "budget_amount" {
  type    = number
  default = 15
}

variable "alert_email" {
  type = string
}

variable "admin_email" {
  description = "Human operator: granted IAP tunnel + OS Login so the tests can SSH into the private VMs."
  type        = string
}

variable "cidrs" {
  description = "One /24 per VPC. Non-overlapping is a hard requirement of Network Connectivity Center."
  type        = map(string)
  default = {
    hub  = "10.0.0.0/24"
    prod = "10.10.0.0/24"
    dev  = "10.20.0.0/24"
  }
}
