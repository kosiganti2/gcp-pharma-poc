output "environment_name" {
  description = "Composer environment name"
  value       = google_composer_environment.pharma_airflow.name
}

output "airflow_uri" {
  description = "Airflow webserver URI"
  value       = google_composer_environment.pharma_airflow.config[0].airflow_uri
  sensitive   = true
}

output "gcs_bucket" {
  description = "Composer GCS bucket"
  value       = google_composer_environment.pharma_airflow.config[0].dag_gcs_prefix
}

output "service_account_email" {
  description = "Composer service account email"
  value       = google_service_account.composer_sa.email
}
