output "topic_names" {
  description = "Created Pub/Sub topic names"
  value = {
    data_ingestion          = google_pubsub_topic.data_ingestion.name
    data_processing         = google_pubsub_topic.data_processing.name
    quality_alerts          = google_pubsub_topic.data_quality_alerts.name
    pipeline_notifications  = google_pubsub_topic.pipeline_notifications.name
  }
}

output "subscription_names" {
  description = "Created Pub/Sub subscription names"
  value = {
    ingestion_trigger = google_pubsub_subscription.data_ingestion_trigger.name
    processing_worker = google_pubsub_subscription.data_processing_worker.name
    quality_alerts    = google_pubsub_subscription.quality_alerts_slack.name
  }
}

output "schema_names" {
  description = "Created Pub/Sub schema names"
  value = {
    data_ingestion = google_pubsub_schema.data_ingestion_schema.name
  }
}
