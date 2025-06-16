output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "gcs_buckets" {
  description = "Created GCS bucket names"
  value = {
    raw_data      = google_storage_bucket.raw_data.name
    processed     = google_storage_bucket.processed_data.name
    code          = google_storage_bucket.code_artifacts.name
    composer_dags = google_storage_bucket.composer_dags.name
  }
}

output "bigquery_dataset" {
  description = "BigQuery dataset information"
  value = {
    dataset_id = google_bigquery_dataset.pharma_analytics.dataset_id
    location   = google_bigquery_dataset.pharma_analytics.location
  }
}

output "pubsub_topics" {
  description = "Created Pub/Sub topics"
  value = {
    data_ingestion         = google_pubsub_topic.data_ingestion.name
    data_processing        = google_pubsub_topic.data_processing.name
    pipeline_notifications = google_pubsub_topic.pipeline_notifications.name
    quality_alerts         = google_pubsub_topic.quality_alerts.name
  }
}

output "monitoring" {
  description = "Monitoring resources"
  value = {
    notification_channel = google_monitoring_notification_channel.email.name
    alert_policy = google_monitoring_alert_policy.storage_usage_alert.name
  }
}
