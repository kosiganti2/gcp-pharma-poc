variable "dataset_name" {}

resource "google_bigquery_dataset" "dataset" {
  dataset_id                 = var.dataset_name
  location                   = "US"
  delete_contents_on_destroy = true
}

output "dataset_name" {
  value = google_bigquery_dataset.dataset.dataset_id
}
