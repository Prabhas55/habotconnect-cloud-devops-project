variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "asia-south1"
}

variable "environment" {
  description = "Deployment environment (staging | production)"
  type        = string
  default     = "staging"
}

variable "ingestion_service_account" {
  description = "Service account email used by the ingestion pipeline to write raw payloads into D0"
  type        = string
}

variable "etl_service_account" {
  description = "Service account email used by ETL jobs to read raw payloads from D0"
  type        = string
}

variable "data_platform_admin_email" {
  description = "Email of the data platform owner (BigQuery OWNER role on D1)"
  type        = string
}

variable "analytics_reader_email" {
  description = "Email of the analytics reader granted RLS-scoped READER access on D1"
  type        = string
}
