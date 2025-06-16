terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Local values for consistent naming
locals {
  environment = var.environment
  labels = {
    environment = local.environment
    project     = "pharma-data-poc"
    created_by  = "terraform"
    team        = "data-engineering"
  }
  prefix = "${var.project_id}-${local.environment}"
}

# Cloud Storage Buckets
resource "google_storage_bucket" "raw_data" {
  name     = "${local.prefix}-raw-data"
  location = var.region
  
  uniform_bucket_level_access = true
  
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
  
  labels = local.labels
}

resource "google_storage_bucket" "processed_data" {
  name     = "${local.prefix}-processed-data"
  location = var.region
  
  uniform_bucket_level_access = true
  
  labels = local.labels
}

resource "google_storage_bucket" "code_artifacts" {
  name     = "${local.prefix}-code-artifacts"
  location = var.region
  
  uniform_bucket_level_access = true
  
  labels = local.labels
}

resource "google_storage_bucket" "composer_dags" {
  name     = "${local.prefix}-composer-dags"
  location = var.region
  
  uniform_bucket_level_access = true
  
  labels = local.labels
}

# BigQuery Dataset
resource "google_bigquery_dataset" "pharma_analytics" {
  dataset_id                  = "${replace(local.prefix, "-", "_")}_analytics"
  location                    = var.region
  description                 = "Pharma analytics dataset for data processing"
  delete_contents_on_destroy  = true
  
  labels = local.labels
}

# BigQuery Tables
resource "google_bigquery_table" "raw_clinical_trials" {
  dataset_id = google_bigquery_dataset.pharma_analytics.dataset_id
  table_id   = "raw_clinical_trials"
  
  schema = jsonencode([
    {
      name = "trial_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "trial_name"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "phase"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "status"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "start_date"
      type = "DATE"
      mode = "NULLABLE"
    },
    {
      name = "end_date"
      type = "DATE"
      mode = "NULLABLE"
    },
    {
      name = "participants"
      type = "INTEGER"
      mode = "NULLABLE"
    },
    {
      name = "created_at"
      type = "TIMESTAMP"
      mode = "NULLABLE"
    }
  ])
  
  labels = local.labels
}

resource "google_bigquery_table" "processed_drug_efficacy" {
  dataset_id = google_bigquery_dataset.pharma_analytics.dataset_id
  table_id   = "processed_drug_efficacy"
  
  schema = jsonencode([
    {
      name = "drug_id"
      type = "STRING"
      mode = "REQUIRED"
    },
    {
      name = "drug_name"
      type = "STRING"
      mode = "NULLABLE"
    },
    {
      name = "efficacy_score"
      type = "FLOAT"
      mode = "NULLABLE"
    },
    {
      name = "trial_count"
      type = "INTEGER"
      mode = "NULLABLE"
    },
    {
      name = "avg_participants"
      type = "FLOAT"
      mode = "NULLABLE"
    },
    {
      name = "success_rate"
      type = "FLOAT"
      mode = "NULLABLE"
    },
    {
      name = "processed_date"
      type = "TIMESTAMP"
      mode = "NULLABLE"
    }
  ])
  
  labels = local.labels
}

# Pub/Sub Topics
resource "google_pubsub_topic" "data_ingestion" {
  name = "${local.prefix}-data-ingestion"
  
  message_retention_duration = "604800s"  # 7 days
  
  labels = local.labels
}

resource "google_pubsub_topic" "data_processing" {
  name = "${local.prefix}-data-processing"
  
  message_retention_duration = "604800s"  # 7 days
  
  labels = local.labels
}

resource "google_pubsub_topic" "pipeline_notifications" {
  name = "${local.prefix}-pipeline-notifications"
  
  message_retention_duration = "259200s"  # 3 days
  
  labels = local.labels
}

resource "google_pubsub_topic" "quality_alerts" {
  name = "${local.prefix}-data-quality-alerts"
  
  message_retention_duration = "86400s"  # 1 day
  
  labels = local.labels
}

# Pub/Sub Subscriptions
resource "google_pubsub_subscription" "data_ingestion_sub" {
  name  = "${local.prefix}-data-ingestion-sub"
  topic = google_pubsub_topic.data_ingestion.name
  
  ack_deadline_seconds = 300  # 5 minutes
  message_retention_duration = "604800s"
  
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }
  
  labels = local.labels
}

resource "google_pubsub_subscription" "data_processing_sub" {
  name  = "${local.prefix}-data-processing-sub"
  topic = google_pubsub_topic.data_processing.name
  
  ack_deadline_seconds = 600  # 10 minutes
  message_retention_duration = "604800s"
  
  retry_policy {
    minimum_backoff = "30s"
    maximum_backoff = "600s"
  }
  
  labels = local.labels
}

# Monitoring
resource "google_monitoring_notification_channel" "email" {
  display_name = "Pharma Pipeline Email Alerts"
  type         = "email"
  
  labels = {
    email_address = var.alert_email
  }
}

# Fixed monitoring alert policy with correct filter syntax
resource "google_monitoring_alert_policy" "storage_usage_alert" {
  display_name = "High Storage Usage - pharma-poc-2024-dev"
  combiner     = "OR"
  
  conditions {
    display_name = "Storage bucket size"
    
    condition_threshold {
      filter         = "resource.type=\"gcs_bucket\""
      duration       = "300s"
      comparison     = "COMPARISON_GT"
      threshold_value = 10737418240  # 10GB in bytes
      
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
  
  notification_channels = [
    google_monitoring_notification_channel.email.name
  ]
  
  alert_strategy {
    auto_close = "1800s"
  }
}
