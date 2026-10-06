variable "project_id" {
  description = "GCP project that will host the runners."
  type        = string
  default     = "advocate-ocr-app"
}

variable "region" {
  description = "Region. asia-south1 = Mumbai (closest to IST, cheap)."
  type        = string
  default     = "asia-south1"
}

variable "zones" {
  description = "Zones the regional MIG may use (spreads runners for reliability)."
  type        = list(string)
  default     = ["asia-south1-a", "asia-south1-b", "asia-south1-c"]
}

variable "name_prefix" {
  description = "Prefix for all resource names."
  type        = string
  default     = "gh-runner"
}

variable "runner_name" {
  description = "Prefix for the GitHub-registered runner name. The actual name becomes '<runner_name>-<instance-hostname>' so multiple runners in the fleet stay unique."
  type        = string
  default     = "gh-runner"
}

# ---------------------------------------------------------------- Compute ---
# The variables below only feed the "gh_runner_mig" module call in main.tf,
# which is currently commented out. Kept (with tflint's unused-variable
# warning suppressed) so re-enabling that module is a one-line uncomment,
# not a re-declare.

variable "machine_type" { # tflint-ignore: terraform_unused_declarations
  description = "e2-medium = 2 vCPU (shared) / 4 GB. Use e2-small for 2 GB."
  type        = string
  default     = "e2-medium"
}

variable "boot_disk_size_gb" { # tflint-ignore: terraform_unused_declarations
  type    = number
  default = 20
}

variable "boot_disk_type" { # tflint-ignore: terraform_unused_declarations
  description = "pd-balanced is the best price/perf default; pd-standard is cheaper but slow for CI."
  type        = string
  default     = "pd-balanced"
}

variable "use_spot" { # tflint-ignore: terraform_unused_declarations
  description = <<-EOT
    Spot VMs are ~60-90% cheaper but can be reclaimed mid-job (30s notice).
    Fine for re-runnable CI; keep false if jobs must not be interrupted.
  EOT
  type        = bool
  default     = false
}

variable "install_ops_agent" { # tflint-ignore: terraform_unused_declarations
  description = "Install the Google Ops Agent so the startup log and system metrics reach Cloud Logging/Monitoring (~150 MB RAM)."
  type        = bool
  default     = true
}

variable "install_docker" { # tflint-ignore: terraform_unused_declarations
  description = "Install Docker Engine on the runners (adds ~1 min to boot)."
  type        = bool
  default     = true
}

# --------------------------------------------------------------- Schedule ---

variable "schedule_cron" { # tflint-ignore: terraform_unused_declarations
  description = "When the runners come UP, in cron format, evaluated in schedule_time_zone. Default: every day 09:00."
  type        = string
  default     = "0 9 * * *"
}

variable "schedule_duration_hours" { # tflint-ignore: terraform_unused_declarations
  description = "How long the fleet stays up after schedule_cron fires. 10h = 09:00 -> 19:00."
  type        = number
  default     = 10
}

variable "schedule_time_zone" { # tflint-ignore: terraform_unused_declarations
  type    = string
  default = "Asia/Kolkata"
}

variable "min_runners" { # tflint-ignore: terraform_unused_declarations
  description = "Runners kept up during the schedule window (0 outside it)."
  type        = number
  default     = 1
}

variable "max_runners" { # tflint-ignore: terraform_unused_declarations
  description = "Upper bound the autoscaler may grow to on CPU load during the window. Also caps cost."
  type        = number
  default     = 3
}

variable "autoscale_cpu_target" { # tflint-ignore: terraform_unused_declarations
  description = "Average CPU (0-1) above which another runner is added."
  type        = number
  default     = 0.6
}

# ----------------------------------------------------------------- GitHub ---

variable "github_owner" {
  description = "GitHub organisation (or user, for repo-level runners)."
  type        = string
  default     = "omanshtechnologies"
}

variable "github_repo" {
  description = "Repository NAME (without owner) to register at repo level. Leave empty for org-level runners."
  type        = string
  default     = ""
}

variable "runner_labels" {
  description = "Extra labels on the runner, comma separated (self-hosted,linux,x64 are added automatically)."
  type        = string
  default     = "self-hosted,insta-crm"
}

variable "runner_version" {
  description = "actions/runner release to install (the runner self-updates after registering)."
  type        = string
  default     = "2.328.0"
}

variable "assign_public_ip" {
  description = "Give each runner an ephemeral public IP (internet reachable). If false, runners are private and egress goes through Cloud NAT."
  type        = bool
  default     = true
}

variable "ssh_members" {
  description = "IAM members (e.g. user:you@example.com) allowed to SSH to runners via OS Login (direct or through IAP). Empty = nobody."
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Extra labels for cost attribution."
  type        = map(string)
  default     = {}
}

# ----------------------------------------------------------------- Server ---

variable "server_name" {
  description = "Name of the standalone VM created by modules/server."
  type        = string
  default     = "gh-runner"
}

variable "server_machine_type" {
  description = "Machine type for the standalone VM created by modules/server."
  type        = string
  default     = "e2-small"
}
