output "gcs_bucket" {
  value = google_storage_bucket.pharma_bucket.name
}

output "bq_dataset" {
  value = google_bigquery_dataset.pharma_dataset.dataset_id
}
