# Pub/Sub topics for event-driven data pipeline
resource "google_pubsub_topic" "data_ingestion" {
  name = "${var.prefix}-data-ingestion"
  
  # Message retention for 7 days
  message_retention_duration = "604800s"
  
  labels = var.labels
}

resource "google_pubsub_topic" "data_processing" {
  name = "${var.prefix}-data-processing"
  
  # Message retention for 7 days
  message_retention_duration = "604800s"
  
  labels = var.labels
}

resource "google_pubsub_topic" "data_quality_alerts" {
  name = "${var.prefix}-data-quality-alerts"
  
  # Shorter retention for alerts (1 day)
  message_retention_duration = "86400s"
  
  labels = var.labels
}

resource "google_pubsub_topic" "pipeline_notifications" {
  name = "${var.prefix}-pipeline-notifications"
  
  # Medium retention for notifications (3 days)
  message_retention_duration = "259200s"
  
  labels = var.labels
}

# Pub/Sub schema for structured data ingestion events
resource "google_pubsub_schema" "data_ingestion_schema" {
  name = "${var.prefix}-data-ingestion-schema"
  type = "AVRO"
  
  definition = jsonencode({
    type = "record"
    name = "DataIngestionEvent"
    fields = [
      {
        name = "file_path"
        type = "string"
      },
      {
        name = "file_size"
        type = "long"
      },
      {
        name = "timestamp"
        type = "long"
      },
      {
        name = "source_system"
        type = "string"
      },
      {
        name = "data_type"
        type = "string"
      },
      {
        name = "priority"
        type = {
          type = "enum"
          name = "Priority"
          symbols = ["LOW", "MEDIUM", "HIGH", "CRITICAL"]
        }
      }
    ]
  })
}

# Subscriptions for different processing workflows

# Data ingestion trigger subscription
resource "google_pubsub_subscription" "data_ingestion_trigger" {
  name  = "${var.prefix}-data-ingestion-trigger"
  topic = google_pubsub_topic.data_ingestion.name
  
  # FIXED: Ack deadline within valid range (10-600 seconds)
  ack_deadline_seconds = 300  # 5 minutes (was 600)
  
  # Message retention for 7 days
  message_retention_duration = "604800s"
  
  # Retry policy for failed messages
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }
  
  labels = var.labels
}

# Data processing worker subscription
resource "google_pubsub_subscription" "data_processing_worker" {
  name  = "${var.prefix}-data-processing-worker"
  topic = google_pubsub_topic.data_processing.name
  
  # FIXED: Ack deadline within valid range (was 1200, now 600)
  ack_deadline_seconds = 600  # 10 minutes (maximum allowed)
  
  # Message retention for 7 days
  message_retention_duration = "604800s"
  
  # Retry policy for long-running processing jobs
  retry_policy {
    minimum_backoff = "30s"
    maximum_backoff = "600s"
  }
  
  labels = var.labels
}

# Quality alerts subscription for Slack notifications
resource "google_pubsub_subscription" "quality_alerts_slack" {
  name  = "${var.prefix}-quality-alerts-slack"
  topic = google_pubsub_topic.data_quality_alerts.name
  
  # Short ack deadline for alerts (should be processed quickly)
  ack_deadline_seconds = 60  # 1 minute
  
  # Message retention for 7 days
  message_retention_duration = "604800s"
  
  labels = var.labels
}

# Pipeline notifications subscription
resource "google_pubsub_subscription" "pipeline_notifications" {
  name  = "${var.prefix}-pipeline-notifications-sub"
  topic = google_pubsub_topic.pipeline_notifications.name
  
  # Medium ack deadline for notifications
  ack_deadline_seconds = 120  # 2 minutes
  
  # Message retention for 3 days
  message_retention_duration = "259200s"
  
  # Retry policy
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "120s"
  }
  
  labels = var.labels
}
