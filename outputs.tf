output "run_url" {
  value = module.google_cloud_run.service.status[0].url
}

output "function_sa_email" {
  value = google_service_account.service_account.email
}

output "function_name" {
  value = var.project_name
}
