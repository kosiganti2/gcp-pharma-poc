# Monitoring dashboard for pharma data pipeline
resource "google_monitoring_dashboard" "pharma_pipeline" {
  dashboard_json = jsonencode({
    displayName = "Pharma Data Pipeline Dashboard"
    mosaicLayout = {
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Data Processing Volume"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"bigquery_dataset\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
                plotType = "LINE"
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Records/sec"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Data Quality Scores"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"bigquery_table\""
                    aggregation = {
                      alignmentPeriod  = "300s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
                plotType = "LINE"
              }]
              yAxis = {
                label = "Quality Score"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}

# Alert policy for data quality issues
resource "google_monitoring_alert_policy" "data_quality_alert" {
  display_name = "Data Quality Alert - ${var.prefix}"
  combiner     = "OR"
  
  conditions {
    display_name = "Low Data Quality Score"
    
    condition_threshold {
      filter         = "resource.type=\"bigquery_table\""
      duration       = "300s"
      comparison     = "COMPARISON_LT"
      threshold_value = 0.8
      
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
  
  notification_channels = [
    google_monitoring_notification_channel.email.name
  ]
  
  alert_strategy {
    auto_close = "1800s"
  }
}

# Email notification channel
resource "google_monitoring_notification_channel" "email" {
  display_name = "Email Notifications"
  type         = "email"
  
  labels = {
    email_address = var.alert_email
  }
}

# Simplified log-based metrics (removed problematic ones)
resource "google_logging_metric" "data_processing_errors" {
  name   = "${var.prefix}-data-processing-errors"
  filter = "resource.type=\"dataproc_cluster\" AND severity=\"ERROR\""
  
  metric_descriptor {
    metric_kind = "GAUGE"
    value_type  = "INT64"
    unit        = "1"
    display_name = "Data Processing Errors"
  }
  
  value_extractor = "EXTRACT(jsonPayload.error_count)"
}
