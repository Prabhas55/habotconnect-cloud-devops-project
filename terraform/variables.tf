###############################################################################
# GCP Project Configuration
###############################################################################

variable "project_id" {

  description = "Google Cloud Project ID"

  type = string

}

variable "region" {

  description = "Google Cloud Region"

  type = string

}

variable "environment" {

  description = "Deployment Environment"

  type = string

  default = "staging"

}

###############################################################################
# Service Accounts
###############################################################################

variable "ingestion_service_account" {

  description = "Service Account used for uploading raw student data"

  type = string

}

variable "etl_service_account" {

  description = "Service Account used by ETL process"

  type = string

}

###############################################################################
# BigQuery Users
###############################################################################

variable "data_platform_admin_email" {

  description = "BigQuery Dataset Owner"

  type = string

}

variable "analytics_reader_email" {

  description = "Analytics User"

  type = string

}
