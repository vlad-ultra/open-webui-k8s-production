provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "apis" {
  for_each = toset([
    "container.googleapis.com",
    "compute.googleapis.com"
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}


resource "google_container_cluster" "cluster" {
  name     = var.cluster_name
  location = var.zone  # Use zone (europe-west1-b), not region (europe-west1) - for minimal creation time
  project  = var.project_id

  # Remove default node pool, use separate node pool
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  logging_service    = "none"
  monitoring_service = "none"

  network    = "default"
  subnetwork = null

  depends_on = [google_project_service.apis]
}

# Separate node pool for applications
resource "google_container_node_pool" "primary" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.cluster.name
  project    = var.project_id
  node_count = var.node_count

  node_config {
    machine_type = "e2-medium"  # 2 CPU, 4 GB RAM - optimized for cost savings
    disk_size_gb = 20
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/compute",
    ]
  }

  depends_on = [google_container_cluster.cluster]
}

resource "google_compute_address" "ingress_ip" {
  name         = "${var.cluster_name}-ingress-ip"
  address_type = "EXTERNAL"
  region       = var.region
  project      = var.project_id

  # Protection from deletion - IP will persist even after terraform destroy
  # This is critical for GitHub Actions to keep IP unchanged on cluster recreation
  # If you need to delete the IP, comment out this block first
  lifecycle {
    prevent_destroy = true
  }
}
