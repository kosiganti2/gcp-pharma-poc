variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}

variable "prefix" {
  description = "Resource naming prefix"
  type        = string
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = "admin@example.com"
}
