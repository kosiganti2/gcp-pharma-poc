resource "google_composer_environment" "composer_env" {
  name    = "pharma-composer"
  region  = var.region
  config {
    node_count = 3
    software_config {
      image_version = "composer-2.1.5-airflow-2.4.3"
    }
  }
}
