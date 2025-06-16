output "bucket_names" {
  description = "Names of created buckets"
  value = {
    raw_data      = google_storage_bucket.raw_data.name
    processed     = google_storage_bucket.processed_data.name
    code          = google_storage_bucket.code_artifacts.name
    composer_dags = google_storage_bucket.composer_dags.name
  }
}

output "dags_bucket_name" {
  description = "Name of the Composer DAGs bucket"
  value       = google_storage_bucket.composer_dags.name
}

output "raw_data_bucket_url" {
  description = "URL of the raw data bucket"
  value       = google_storage_bucket.raw_data.url
}
