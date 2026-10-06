output "mig_name" {
  value = google_compute_region_instance_group_manager.runners.name
}

output "instance_template_self_link" {
  value = google_compute_instance_template.runner.self_link
}
