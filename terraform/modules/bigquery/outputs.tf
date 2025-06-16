output "dataset_id" {
  description = "BigQuery dataset ID"
  value       = google_bigquery_dataset.pharma_analytics.dataset_id
}

output "location" {
  description = "BigQuery dataset location"
  value       = google_bigquery_dataset.pharma_analytics.location
}

output "table_ids" {
  description = "Created BigQuery table IDs"
  value = {
    raw_data    = google_bigquery_table.cms_drug_raw.table_id
    enriched    = google_bigquery_table.cms_drug_enriched.table_id
    analytics   = google_bigquery_table.drug_market_analysis.table_id
    quality     = google_bigquery_table.data_quality_metrics.table_id
  }
}

output "dataset_url" {
  description = "BigQuery dataset URL"
  value       = "https://console.cloud.google.com/bigquery?project=${var.project_id}&ws=!1m4!1m3!3m2!1s${var.project_id}!2s${google_bigquery_dataset.pharma_analytics.dataset_id}"
}
