resource "google_bigquery_dataset" "pharma_dataset" {
  dataset_id = "pharma_data"
  location   = var.region
}
