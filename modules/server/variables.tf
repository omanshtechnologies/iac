variable "name" {
  description = "Name of the VM instance."
  type        = string
}

variable "project_id" {
  type = string
}

variable "zone" {
  description = "Zone the VM is created in, e.g. 'asia-south1-a'."
  type        = string
}

variable "machine_type" {
  type    = string
  default = "e2-small"
}

variable "subnetwork_id" {
  description = "Subnetwork the VM attaches to."
  type        = string
}

variable "assign_public_ip" {
  description = "Give the VM an ephemeral public IP."
  type        = bool
  default     = true
}

variable "boot_disk_image" {
  type    = string
  default = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "boot_disk_size_gb" {
  type    = number
  default = 20
}

variable "boot_disk_type" {
  type    = string
  default = "pd-balanced"
}

variable "service_account_email" {
  description = "Service account to attach to the VM. Leave null for no attached service account (default, most secure)."
  type        = string
  default     = null
}

variable "service_account_scopes" {
  type    = list(string)
  default = ["cloud-platform"]
}

variable "metadata_startup_script" {
  description = "Extra startup script content, appended after the built-in docker/java/maven provisioning."
  type        = string
  default     = null
}

variable "install_docker" {
  description = "Install Docker Engine + the docker compose plugin."
  type        = bool
  default     = true
}

variable "install_java" {
  description = "Install OpenJDK 17."
  type        = bool
  default     = true
}

variable "install_maven" {
  description = "Install Maven."
  type        = bool
  default     = true
}

# ------------------------------------------------------- GitHub runner ---

variable "register_as_gh_runner" {
  description = "Register this VM as a GitHub Actions self-hosted runner on boot."
  type        = bool
  default     = true
}

variable "secret_id" {
  description = "Secret Manager secret id/short-name holding the GitHub PAT (required when register_as_gh_runner is true)."
  type        = string
  default     = ""
}

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

variable "runner_name" {
  description = "Prefix for the GitHub-registered runner name. The actual name becomes '<runner_name>-<instance-hostname>'."
  type        = string
  default     = "gh-runner"
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

variable "metadata" {
  description = "Extra instance metadata key/value pairs."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Network tags, used for firewall targeting."
  type        = list(string)
  default     = []
}

variable "labels" {
  type    = map(string)
  default = {}
}
