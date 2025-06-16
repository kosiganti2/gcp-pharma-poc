output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

output "gcs_buckets" {
  description = "Created GCS bucket names"
  value       = module.gcs.bucket_names
}

output "bigquery_dataset" {
  description = "BigQuery dataset information"
  value = {
    dataset_id = module.bigquery.dataset_id
    location   = module.bigquery.location
  }
}

output "composer_environment" {
  description = "Composer environment details"
  value = {
    name   = module.composer.environment_name
    uri    = module.composer.airflow_uri
    bucket = module.composer.gcs_bucket
  }
  sensitive = true
}

output "pubsub_topics" {
  description = "Created Pub/Sub topics"
  value       = module.pubsub.topic_names
}

output "monitoring_dashboards" {
  description = "Monitoring dashboard URLs"
  value       = module.monitoring.dashboard_urls
}
