# Dedicated, least-privilege identity for the runner VMs.
resource "google_service_account" "runner" {
  account_id   = "${var.name_prefix}-sa"
  display_name = "GitHub Actions runner VMs"
  depends_on   = [google_project_service.apis]
}

resource "google_project_iam_member" "runner_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

resource "google_project_iam_member" "runner_metrics" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.runner.email}"
}

# Read ONLY the one GitHub token secret.
resource "google_secret_manager_secret_iam_member" "runner_secret" {
  secret_id = google_secret_manager_secret.github_pat.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runner.email}"
}

# Optional human SSH access: IAP tunnel + OS Login (no static SSH keys).
resource "google_project_iam_member" "iap_tunnel" {
  for_each = toset(var.ssh_members)
  project  = var.project_id
  role     = "roles/iap.tunnelResourceAccessor"
  member   = each.value
}

resource "google_project_iam_member" "os_login" {
  for_each = toset(var.ssh_members)
  project  = var.project_id
  role     = "roles/compute.osLogin"
  member   = each.value
}

resource "google_service_account_iam_member" "os_login_sa_user" {
  for_each           = toset(var.ssh_members)
  service_account_id = google_service_account.runner.name
  role               = "roles/iam.serviceAccountUser"
  member             = each.value
}
