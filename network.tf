# Use the project's existing default network/subnet instead of creating a
# dedicated VPC. Relies on GCP's built-in default firewall rules
# (default-allow-ssh, default-allow-internal, default-allow-icmp) already
# present on that network to cover SSH, IAP SSH, and MIG health-check probes
# (all tcp/22, all subsets of default-allow-ssh's 0.0.0.0/0). If that rule
# has been removed/narrowed on your project, re-add dedicated rules.
data "google_compute_network" "default" {
  name       = "default"
  project    = var.project_id
  depends_on = [google_project_service.apis]
}

data "google_compute_subnetwork" "default" {
  name       = "default"
  region     = var.region
  project    = var.project_id
  depends_on = [google_project_service.apis]
}

# Only needed when runners have no public IP: outbound internet via Cloud NAT.
resource "google_compute_router" "router" {
  count   = var.assign_public_ip ? 0 : 1
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = data.google_compute_network.default.id
}

resource "google_compute_router_nat" "nat" {
  count                              = var.assign_public_ip ? 0 : 1
  name                               = "${var.name_prefix}-nat"
  router                             = google_compute_router.router[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = data.google_compute_subnetwork.default.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
