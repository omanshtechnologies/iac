terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

locals {
  labels = merge({ managed-by = "terraform", purpose = "github-runner" }, var.labels)

  github_url = var.github_repo == "" ? "https://github.com/${var.github_owner}" : "https://github.com/${var.github_owner}/${var.github_repo}"
  github_api = var.github_repo == "" ? "orgs/${var.github_owner}" : "repos/${var.github_owner}/${var.github_repo}"

  common_script = templatefile("${path.module}/scripts/runner-common.sh.tpl", {
    project_id = var.project_id
    secret_id  = var.secret_id
    github_api = local.github_api
  })

  startup_script = templatefile("${path.module}/scripts/startup.sh.tpl", {
    common_script     = local.common_script
    github_url        = local.github_url
    runner_version    = var.runner_version
    runner_name       = var.runner_name
    runner_labels     = var.runner_labels
    install_docker    = var.install_docker
    install_ops_agent = var.install_ops_agent
  })
}

# ------------------------------------------------------- Instance template ---

resource "google_compute_instance_template" "runner" {
  name_prefix  = "${var.name_prefix}-"
  region       = var.region
  machine_type = var.machine_type
  labels       = local.labels

  disk {
    # Family (not a pinned image): VMs are recreated every morning, so each day
    # starts from the latest patched Ubuntu 24.04 LTS.
    source_image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    boot         = true
    auto_delete  = true
    disk_size_gb = var.boot_disk_size_gb
    disk_type    = var.boot_disk_type
    labels       = local.labels
  }

  network_interface {
    subnetwork = var.subnetwork_id

    # Ephemeral public IP (billed only while the VM runs). Without it, egress
    # goes through Cloud NAT instead.
    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {}
    }
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"] # real permissions are limited by IAM roles in iam.tf
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  scheduling {
    provisioning_model          = var.use_spot ? "SPOT" : "STANDARD"
    preemptible                 = var.use_spot
    automatic_restart           = !var.use_spot
    on_host_maintenance         = var.use_spot ? "TERMINATE" : "MIGRATE"
    instance_termination_action = var.use_spot ? "DELETE" : null
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
    serial-port-enable     = "FALSE"
    startup-script         = local.startup_script
    shutdown-script        = <<-EOT
      #!/bin/bash
      /usr/local/bin/runner-deregister.sh || true
    EOT
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------ Auto-healing ---

# Replaces VMs that hang or lose networking. (The runner exposes no port, so the
# check is TCP/22; sshd is only reachable by Google's probe ranges + IAP.)
resource "google_compute_health_check" "vm_alive" {
  name                = "${var.name_prefix}-vm-alive"
  check_interval_sec  = 30
  timeout_sec         = 10
  healthy_threshold   = 2
  unhealthy_threshold = 5

  tcp_health_check {
    port = 22
  }
}

# ------------------------------------------------------------------- MIG ---

resource "google_compute_region_instance_group_manager" "runners" {
  name                      = "${var.name_prefix}-mig"
  region                    = var.region
  base_instance_name        = var.name_prefix
  distribution_policy_zones = var.zones

  # Spot capacity is easier to find when the MIG may pick any zone.
  distribution_policy_target_shape = var.use_spot ? "ANY" : "EVEN"

  # target_size intentionally omitted: the autoscaler owns the size.

  version {
    instance_template = google_compute_instance_template.runner.id
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.vm_alive.id
    initial_delay_sec = 600 # allow for the startup script (apt + runner install)
  }

  # New templates apply to VMs created from now on. Because the fleet is
  # recreated every morning anyway, running jobs are never interrupted by a rollout.
  update_policy {
    type                         = "OPPORTUNISTIC"
    minimal_action               = "REPLACE"
    replacement_method           = "SUBSTITUTE"
    instance_redistribution_type = "NONE" # never kill a busy runner just to rebalance zones
    max_unavailable_fixed        = length(var.zones)
    max_surge_fixed              = length(var.zones)
  }

  lifecycle {
    ignore_changes = [target_size]
  }
}

# -------------------------------------------------------------- Scheduling ---

# 0 VMs outside the window (no compute billing), min_runners inside it,
# growing up to max_runners on CPU load.
resource "google_compute_region_autoscaler" "runners" {
  name   = "${var.name_prefix}-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.runners.id

  autoscaling_policy {
    min_replicas    = 0
    max_replicas    = var.max_runners
    cooldown_period = 120
    mode            = "ON"

    cpu_utilization {
      target = var.autoscale_cpu_target
    }

    # Remove at most one runner per 5 minutes so a burst of scale-in cannot
    # kill several busy runners at once.
    scale_in_control {
      time_window_sec = 300
      max_scaled_in_replicas {
        fixed = 1
      }
    }

    scaling_schedules {
      name                  = "business-hours"
      description           = "Runners up ${var.schedule_cron} for ${var.schedule_duration_hours}h (${var.schedule_time_zone})"
      schedule              = var.schedule_cron
      time_zone             = var.schedule_time_zone
      duration_sec          = var.schedule_duration_hours * 3600
      min_required_replicas = var.min_runners
    }
  }

  lifecycle {
    precondition {
      condition     = var.max_runners >= var.min_runners && var.max_runners >= 1
      error_message = "max_runners must be >= min_runners and >= 1."
    }
  }
}
