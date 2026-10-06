variable "project_id" {
  description = "GCP project that will host the runners."
  type        = string
}

variable "region" {
  type = string
}

variable "zones" {
  description = "Zones the regional MIG may use (spreads runners for reliability)."
  type        = list(string)
}

variable "name_prefix" {
  description = "Prefix for all resource names."
  type        = string
}

variable "runner_name" {
  description = "Prefix for the GitHub-registered runner name. The actual name becomes '<runner_name>-<instance-hostname>' so multiple runners in the fleet stay unique."
  type        = string
}

variable "subnetwork_id" {
  description = "Subnetwork the runner instances attach to."
  type        = string
}

variable "service_account_email" {
  description = "Service account email attached to the runner instances."
  type        = string
}

variable "secret_id" {
  description = "Secret Manager secret id/short-name holding the GitHub PAT."
  type        = string
}

# ---------------------------------------------------------------- Compute ---

variable "machine_type" {
  description = "e2-medium = 2 vCPU (shared) / 4 GB. Use e2-small for 2 GB."
  type        = string
}

variable "boot_disk_size_gb" {
  type = number
}

variable "boot_disk_type" {
  description = "pd-balanced is the best price/perf default; pd-standard is cheaper but slow for CI."
  type        = string
}

variable "use_spot" {
  description = <<-EOT
    Spot VMs are ~60-90% cheaper but can be reclaimed mid-job (30s notice).
    Fine for re-runnable CI; keep false if jobs must not be interrupted.
  EOT
  type        = bool
}

variable "install_ops_agent" {
  description = "Install the Google Ops Agent so the startup log and system metrics reach Cloud Logging/Monitoring (~150 MB RAM)."
  type        = bool
}

variable "install_docker" {
  description = "Install Docker Engine on the runners (adds ~1 min to boot)."
  type        = bool
}

variable "assign_public_ip" {
  description = "Give each runner an ephemeral public IP (internet reachable). If false, runners are private and egress goes through Cloud NAT."
  type        = bool
}

# --------------------------------------------------------------- Schedule ---

variable "schedule_cron" {
  description = "When the runners come UP, in cron format, evaluated in schedule_time_zone."
  type        = string
}

variable "schedule_duration_hours" {
  description = "How long the fleet stays up after schedule_cron fires."
  type        = number
}

variable "schedule_time_zone" {
  type = string
}

variable "min_runners" {
  description = "Runners kept up during the schedule window (0 outside it)."
  type        = number
}

variable "max_runners" {
  description = "Upper bound the autoscaler may grow to on CPU load during the window. Also caps cost."
  type        = number
}

variable "autoscale_cpu_target" {
  description = "Average CPU (0-1) above which another runner is added."
  type        = number
}

# ----------------------------------------------------------------- GitHub ---

variable "github_owner" {
  description = "GitHub organisation (or user, for repo-level runners)."
  type        = string
}

variable "github_repo" {
  description = "Repository NAME (without owner) to register at repo level. Leave empty for org-level runners."
  type        = string
}

variable "runner_labels" {
  description = "Extra labels on the runner, comma separated (self-hosted,linux,x64 are added automatically)."
  type        = string
}

variable "runner_version" {
  description = "actions/runner release to install (the runner self-updates after registering)."
  type        = string
}

variable "labels" {
  description = "Extra GCE resource labels for cost attribution."
  type        = map(string)
  default     = {}
}
