variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west1"  
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "europe-west1-b"  
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "open-webui-cluster"
}

variable "node_count" {
  description = "Initial number of nodes"
  type        = number
  default     = 2
}

variable "openrouter_api_key" {
  description = "OpenRouter API key for 344+ AI models (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "gcp_sa_key" {
  description = "GCP Service Account JSON key for initContainer to access GCS (optional, can be set via environment)"
  type        = string
  default     = ""
  sensitive   = true
}
