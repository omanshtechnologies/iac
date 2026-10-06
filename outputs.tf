# output "mig_name" {
#   value = module.gh_runner_mig.mig_name
# }

output "server_name" {
  value = module.server.name
}

output "server_internal_ip" {
  value = module.server.internal_ip
}

output "runner_service_account" {
  value = google_service_account.runner.email
}

output "github_token_secret" {
  description = "Secret that must hold the GitHub token (add a version after the first apply)."
  value       = google_secret_manager_secret.github_pat.id
}

output "add_token_command" {
  description = "Run this once to store your GitHub token (paste it on stdin, it never touches Terraform state)."
  value       = "printf '%s' \"$GITHUB_PAT\" | gcloud secrets versions add ${google_secret_manager_secret.github_pat.secret_id} --project=${var.project_id} --data-file=-"
}
