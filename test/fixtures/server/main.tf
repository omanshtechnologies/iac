# Test fixture: wraps modules/server with a self-contained provider config
# and placeholder values, so `terraform plan` can run completely offline.
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = "test-project"
  region  = "asia-south1"
}

module "under_test" {
  source = "../../../modules/server"

  name          = "server-test"
  project_id    = "test-project"
  zone          = "asia-south1-a"
  machine_type  = "e2-small"
  subnetwork_id = "projects/test-project/regions/asia-south1/subnetworks/default"

  labels = {}
}
