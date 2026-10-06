# Terraform creates only the empty secret. The token VALUE is added out-of-band
# (see README) so it never lands in Terraform state or git.
resource "google_secret_manager_secret" "github_pat" {
  secret_id = "${var.name_prefix}-github-pat"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels     = local.labels
  depends_on = [google_project_service.apis]
}
