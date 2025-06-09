resource "google_storage_bucket" "pharma_bucket" {
  name     = "${var.project_id}-pharma-bucket"
  location = var.region
}
