provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "pharma_data_bucket" {
  name     = "${var.project_id}-pharma-data-bucket"
  location = var.region
}
