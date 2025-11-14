output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.cluster.name
}

output "cluster_zone" {
  description = "GKE cluster zone"
  value       = google_container_cluster.cluster.location
}

output "kubectl_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.cluster.name} --zone ${google_container_cluster.cluster.location} --project ${var.project_id}"
}

output "ingress_ip" {
  description = "Static IP address for Ingress LoadBalancer"
  value       = google_compute_address.ingress_ip.address
}

output "ingress_ip_name" {
  description = "Name of the static IP address resource"
  value       = google_compute_address.ingress_ip.name
}
