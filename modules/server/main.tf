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
  labels = merge({ managed-by = "terraform", purpose = "server" }, var.labels)

  github_url = var.github_repo == "" ? "https://github.com/${var.github_owner}" : "https://github.com/${var.github_owner}/${var.github_repo}"
  github_api = var.github_repo == "" ? "orgs/${var.github_owner}" : "repos/${var.github_owner}/${var.github_repo}"

  common_script = templatefile("${path.module}/scripts/runner-common.sh.tpl", {
    project_id = var.project_id
    secret_id  = var.secret_id
    github_api = local.github_api
  })

  provisioning_script = templatefile("${path.module}/scripts/startup.sh.tpl", {
    install_docker        = var.install_docker
    install_java          = var.install_java
    install_maven         = var.install_maven
    register_as_gh_runner = var.register_as_gh_runner
    common_script         = local.common_script
    github_url            = local.github_url
    runner_name           = var.runner_name
    zone                  = var.zone
    runner_labels         = var.runner_labels
    runner_version        = var.runner_version
  })

  startup_script = var.metadata_startup_script == null ? local.provisioning_script : "${local.provisioning_script}\n${var.metadata_startup_script}"
}

resource "google_compute_instance" "vm" {
  name         = var.name
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type
  labels       = local.labels
  tags         = var.tags

  boot_disk {
    initialize_params {
      image = var.boot_disk_image
      size  = var.boot_disk_size_gb
      type  = var.boot_disk_type
    }
  }

  network_interface {
    subnetwork = var.subnetwork_id

    dynamic "access_config" {
      for_each = var.assign_public_ip ? [1] : []
      content {}
    }
  }

  dynamic "service_account" {
    for_each = var.service_account_email == null ? [] : [var.service_account_email]
    content {
      email  = service_account.value
      scopes = var.service_account_scopes
    }
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # OS Login disabled (and project-wide SSH keys left unblocked) so anyone who
  # can add an SSH key to the project/instance metadata can connect, rather
  # than requiring a per-user OS Login IAM grant.
  metadata = merge(
    {
      enable-oslogin  = "FALSE"
      shutdown-script = <<-EOT
        #!/bin/bash
        /usr/local/bin/runner-deregister.sh || true
      EOT
    },
    var.metadata
  )

  metadata_startup_script = local.startup_script
}
