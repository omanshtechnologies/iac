# Test fixture: wraps modules/gh-runner-mig with a self-contained provider
# config and placeholder values, so `terraform plan` can run completely
# offline (no real GCP project/credentials needed) — every resource in the
# module is a create-only resource, no data sources.
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
  source = "../../../modules/gh-runner-mig"

  project_id            = "test-project"
  region                = "asia-south1"
  zones                 = ["asia-south1-a", "asia-south1-b", "asia-south1-c"]
  name_prefix           = "gh-runner-test"
  runner_name           = "gh-runner-test"
  subnetwork_id         = "projects/test-project/regions/asia-south1/subnetworks/default"
  service_account_email = "test-sa@test-project.iam.gserviceaccount.com"
  secret_id             = "gh-runner-test-github-pat"

  machine_type      = "e2-medium"
  boot_disk_size_gb = 20
  boot_disk_type    = "pd-balanced"
  use_spot          = false
  install_ops_agent = true
  install_docker    = false
  assign_public_ip  = true

  schedule_cron           = "0 9 * * *"
  schedule_duration_hours = 10
  schedule_time_zone      = "Asia/Kolkata"
  min_runners             = 1
  max_runners             = 3
  autoscale_cpu_target    = 0.6

  github_owner   = "test-org"
  github_repo    = ""
  runner_labels  = "gcp,test"
  runner_version = "2.328.0"

  labels = {}
}
