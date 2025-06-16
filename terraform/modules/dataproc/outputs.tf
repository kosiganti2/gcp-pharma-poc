output "cluster_name" {
  description = "Dataproc cluster name"
  value       = google_dataproc_cluster.pharma_processing.name
}

output "cluster_region" {
  description = "Dataproc cluster region"
  value       = google_dataproc_cluster.pharma_processing.region
}

output "service_account_email" {
  description = "Dataproc service account email"
  value       = google_service_account.dataproc_sa.email
}

output "autoscaling_policy" {
  description = "Autoscaling policy ID"
  value       = google_dataproc_autoscaling_policy.pharma_autoscaling.policy_id
}

output "cluster_url" {
  description = "Dataproc cluster URL in console"
  value       = "https://console.cloud.google.com/dataproc/clusters/details/${var.region}/${google_dataproc_cluster.pharma_processing.name}?project=${var.project_id}"
}
