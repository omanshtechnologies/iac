# module "gh_runner_mig" {
#   source = "./modules/gh-runner-mig"
#
#   project_id            = var.project_id
#   region                = var.region
#   zones                 = var.zones
#   name_prefix           = var.name_prefix
#   runner_name           = var.runner_name
#   subnetwork_id         = data.google_compute_subnetwork.default.id
#   service_account_email = google_service_account.runner.email
#   secret_id             = google_secret_manager_secret.github_pat.secret_id
#
#   machine_type      = var.machine_type
#   boot_disk_size_gb = var.boot_disk_size_gb
#   boot_disk_type    = var.boot_disk_type
#   use_spot          = var.use_spot
#   install_ops_agent = var.install_ops_agent
#   install_docker    = var.install_docker
#   assign_public_ip  = var.assign_public_ip
#
#   schedule_cron           = var.schedule_cron
#   schedule_duration_hours = var.schedule_duration_hours
#   schedule_time_zone      = var.schedule_time_zone
#   min_runners             = var.min_runners
#   max_runners             = var.max_runners
#   autoscale_cpu_target    = var.autoscale_cpu_target
#
#   github_owner   = var.github_owner
#   github_repo    = var.github_repo
#   runner_labels  = var.runner_labels
#   runner_version = var.runner_version
#
#   labels = var.labels
# }

# Standalone VM (replaces the gh-runner-mig fleet above) built from the
# modules/server module. Public IP, open SSH (no OS Login), and registers
# itself as a GitHub Actions runner on boot, alongside docker/java/maven.
module "server" {
  source = "./modules/server"

  name                  = var.server_name
  project_id            = var.project_id
  zone                  = var.zones[0]
  machine_type          = var.server_machine_type
  subnetwork_id         = data.google_compute_subnetwork.default.id
  assign_public_ip      = true
  service_account_email = google_service_account.runner.email

  register_as_gh_runner = true
  secret_id             = google_secret_manager_secret.github_pat.secret_id
  github_owner          = var.github_owner
  github_repo           = var.github_repo
  runner_name           = var.runner_name
  runner_labels         = var.runner_labels
  runner_version        = var.runner_version

  labels = var.labels
}
