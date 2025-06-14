variable "cluster_name" {}
variable "bucket_name" {}

resource "google_dataproc_cluster" "cluster" {
  name   = var.cluster_name
  region = "us-central1"

  cluster_config {
    staging_bucket = var.bucket_name

    master_config {
      num_instances = 1
      machine_type  = "n1-standard-2"
      disk_config {
        boot_disk_size_gb = 50
      }
    }

    worker_config {
      num_instances = 2
      machine_type  = "n1-standard-2"
      disk_config {
        boot_disk_size_gb = 50
      }
    }

    software_config {
      image_version = "2.0-debian10"
    }
  }
}

output "cluster_name" {
  value = google_dataproc_cluster.cluster.name
}
