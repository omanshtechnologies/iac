terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Remote state. Bucket/prefix are supplied at `terraform init` time via
  # -backend-config (see .github/workflows/deploy-runners.yml), since backend
  # blocks cannot reference variables.
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}
