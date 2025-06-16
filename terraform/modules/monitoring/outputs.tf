output "dashboard_urls" {
  description = "Monitoring dashboard URLs"
  value = {
    main_dashboard = "https://console.cloud.google.com/monitoring/dashboards/custom/${google_monitoring_dashboard.pharma_pipeline.id}"
  }
}

output "alert_policies" {
  description = "Created alert policy names"
  value = {
    data_quality = google_monitoring_alert_policy.data_quality_alert.name
  }
}

output "notification_channels" {
  description = "Created notification channels"
  value = {
    email = google_monitoring_notification_channel.email.name
  }
}
