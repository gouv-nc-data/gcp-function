output "run_url" {
  value = local.create_job ? null : module.google_cloud_run.service_uri
}

output "function_sa_email" {
  value = google_service_account.service_account.email
}

output "vpc_network_name" {
  value = one(google_compute_network.vpc_network[*].name)
}

output "ip" {
  value = one(google_compute_address.default[*].address)
}

output "function_name" {
  value = var.project_name
}
