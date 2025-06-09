resource "google_notebooks_instance" "pharma_notebook" {
  name        = "pharma-notebook"
  location    = var.region
  machine_type = "n1-standard-4"
  vm_image {
    project      = "deeplearning-platform-release"
    image_family = "common-cpu"
  }
}
