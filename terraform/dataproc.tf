resource "google_dataproc_cluster" "pharma_cluster" {
  name   = "pharma-dataproc"
  region = var.region

  cluster_config {
    master_config {
      num_instances = 1
      machine_type  = "n1-standard-2"
    }
    worker_config {
      num_instances = 2
      machine_type  = "n1-standard-2"
    }
  }
}
