terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Local values for consistent naming
locals {
  environment = var.environment
  timestamp   = formatdate("YYYYMMDD-hhmm", timestamp())
  labels = {
    environment = local.environment
    project     = "pharma-data-poc"
    created_by  = "terraform"
    team        = "data-engineering"
  }
  
  # Resource naming convention
  prefix = "${var.project_id}-${local.environment}"
}

# Data sources
data "google_project" "current" {}
data "google_client_config" "default" {}

# Module instantiations
module "gcs" {
  source = "./modules/gcs"
  
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.labels
  prefix      = local.prefix
}

module "bigquery" {
  source = "./modules/bigquery"
  
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.labels
  prefix      = local.prefix
}

module "dataproc" {
  source = "./modules/dataproc"
  
  project_id  = var.project_id
  region      = var.region
  zone        = var.zone
  environment = var.environment
  labels      = local.labels
  prefix      = local.prefix
  
  depends_on = [module.gcs]
}

module "composer" {
  source = "./modules/composer"
  
  project_id          = var.project_id
  region              = var.region
  zone                = var.zone
  environment         = var.environment
  labels              = local.labels
  prefix              = local.prefix
  gcs_bucket_name     = module.gcs.dags_bucket_name
  bigquery_dataset_id = module.bigquery.dataset_id
  slack_webhook_url   = var.slack_webhook_url
  
  depends_on = [module.gcs, module.bigquery]
}

module "pubsub" {
  source = "./modules/pubsub"
  
  project_id  = var.project_id
  region      = var.region
  environment = var.environment
  labels      = local.labels
  prefix      = local.prefix
}

module "monitoring" {
  source = "./modules/monitoring"
  
  project_id  = var.project_id
  environment = var.environment
  labels      = local.labels
  prefix      = local.prefix
  alert_email = "srinikosi@gmail.com"
}
