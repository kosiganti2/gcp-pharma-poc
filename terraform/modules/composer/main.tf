# Cloud Composer environment for workflow orchestration
resource "google_composer_environment" "pharma_airflow" {
  name   = "${var.prefix}-composer-env"
  region = var.region
  
  config {
    # Node configuration
    node_config {
      zone         = var.zone
      machine_type = "n1-standard-2"
      disk_size_gb = 100
      
      # Service account
      service_account = google_service_account.composer_sa.email
      
      # Tags for networking
      tags = ["composer", "airflow", "pharma-etl"]
    }
    
    # Software configuration
    software_config {
      image_version = "composer-2-airflow-2"
      
      # Python packages for data processing
      pypi_packages = {
        "google-cloud-bigquery"     = ">=3.11.0"
        "google-cloud-storage"      = ">=2.10.0"
        "google-cloud-dataproc"     = ">=5.4.0"
        "pandas"                    = ">=2.0.0"
        "numpy"                     = ">=1.24.0"
        "great-expectations"        = ">=0.17.0"
        "apache-airflow-providers-google" = ">=10.0.0"
        "structlog"                 = ">=23.1.0"
        "pydantic"                  = ">=2.0.0"
      }
      
      # Airflow configuration
      airflow_config_overrides = {
        "core-dags_are_paused_at_creation" = "False"
        "core-max_active_runs_per_dag"     = "3"
        "core-max_active_tasks_per_dag"    = "10"
        "scheduler-catchup_by_default"     = "False"
        "webserver-expose_config"          = "True"
        "email-email_backend"              = "airflow.providers.sendgrid.utils.emailer.send_email"
        "logging-remote_logging"           = "True"
        "logging-remote_base_log_folder"   = "gs://${var.gcs_bucket_name}/logs"
      }
      
      # Environment variables
      env_variables = {
        "PROJECT_ID"           = var.project_id
        "REGION"              = var.region
        "BIGQUERY_DATASET"    = var.bigquery_dataset_id
        "ENVIRONMENT"         = var.environment
        "DATA_BUCKET"         = "${var.prefix}-raw-data"
        "PROCESSED_BUCKET"    = "${var.prefix}-processed-data"
        "SLACK_WEBHOOK_URL"   = var.slack_webhook_url
      }
    }
    
    # Resource allocation
    node_count = 3
    
    # Database configuration
    database_config {
      machine_type = "db-n1-standard-2"
      zone         = var.zone
    }
    
    # Web server configuration
    web_server_config {
      machine_type = "composer-n1-webserver-2"
    }
  }
  
  labels = var.labels
  
  lifecycle {
    prevent_destroy = false
  }
}

# Service account for Composer - FIXED NAME
resource "google_service_account" "composer_sa" {
  account_id   = "pharma-composer-sa"
  display_name = "Cloud Composer Service Account"
  description  = "Service account for Cloud Composer environment"
}

# IAM roles for Composer service account
resource "google_project_iam_member" "composer_worker" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

resource "google_project_iam_member" "dataproc_editor" {
  project = var.project_id
  role    = "roles/dataproc.editor"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

resource "google_project_iam_member" "bigquery_data_editor" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

resource "google_project_iam_member" "storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}
