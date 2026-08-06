###############################################################################
# Terraform Configuration
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30"
    }
  }
}

###############################################################################
# Google Cloud Provider
###############################################################################

provider "google" {
  project = var.project_id
  region  = var.region
}

###############################################################################
# Current Project Information
###############################################################################

data "google_project" "current" {}

###############################################################################
# Service Accounts
###############################################################################

# Uploads raw student onboarding JSON into D0.

resource "google_service_account" "ingestion_sa" {

  account_id   = var.ingestion_service_account
  display_name = "Student Ingestion Service Account"

  description = "Uploads raw onboarding payloads into D0 Raw Landing"

}

###############################################################################

# Reads raw files and loads validated data into BigQuery.

resource "google_service_account" "etl_sa" {

  account_id   = var.etl_service_account
  display_name = "Student ETL Service Account"

  description = "Processes D0 data into D1 BigQuery"

}

###############################################################################
# Cloud KMS
###############################################################################

resource "google_kms_key_ring" "raw_landing_ring" {

  name     = "d0-raw-landing-keyring"
  location = var.region

}

resource "google_kms_crypto_key" "raw_landing_key" {

  name     = "d0-raw-landing-key"

  key_ring = google_kms_key_ring.raw_landing_ring.id

  rotation_period = "7776000s"

  lifecycle {

    prevent_destroy = true

  }

}

###############################################################################
# Allow Google Cloud Storage to use the KMS key
###############################################################################

resource "google_kms_crypto_key_iam_binding" "storage_kms" {

  crypto_key_id = google_kms_crypto_key.raw_landing_key.id

  role = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [

    "serviceAccount:service-${data.google_project.current.number}@gs-project-accounts.iam.gserviceaccount.com"

  ]

}



###############################################################################
# D0 - Raw Landing Bucket (Google Cloud Storage)
#
# Purpose:
# Secure landing zone for raw student onboarding JSON payloads
# before validation and ETL processing.
###############################################################################

resource "google_storage_bucket" "d0_raw_landing" {

  name     = "${var.project_id}-d0-raw-landing"
  location = var.region

  storage_class = "STANDARD"

  force_destroy = false

  uniform_bucket_level_access = true

  labels = {
    stage       = "d0-raw"
    environment = var.environment
    managed_by  = "terraform"
  }

  ###########################################################################
  # Enable Object Versioning
  ###########################################################################

  versioning {
    enabled = true
  }

  ###########################################################################
  # Lifecycle Rule
  #
  # Automatically delete raw payloads after 30 days.
  ###########################################################################

  lifecycle_rule {

    condition {
      age = 30
    }

    action {
      type = "Delete"
    }

  }

  ###########################################################################
  # Customer Managed Encryption
  ###########################################################################

  encryption {

    default_kms_key_name =
      google_kms_crypto_key.raw_landing_key.id

  }

}

###############################################################################
# IAM
#
# Ingestion Service Account
#
# Least Privilege:
#
# Can:
#   ✓ Upload files
#
# Cannot:
#   ✗ Read files
#   ✗ Delete files
#   ✗ List bucket
#
# Uploads are restricted to the /incoming/ prefix only.
###############################################################################

resource "google_storage_bucket_iam_member" "d0_writer" {

  bucket = google_storage_bucket.d0_raw_landing.name

  role = "roles/storage.objectCreator"

  member =
    "serviceAccount:${google_service_account.ingestion_sa.email}"

  condition {

    title = "write_only_incoming"

    description =
      "Allow uploads only inside incoming/ folder"

    expression =
      "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.d0_raw_landing.name}/objects/incoming/\")"

  }

}

###############################################################################
# ETL Service Account
#
# Read-only access to D0.
#
# ETL can read raw files but cannot modify or delete them.
###############################################################################

resource "google_storage_bucket_iam_member" "d0_reader" {

  bucket = google_storage_bucket.d0_raw_landing.name

  role = "roles/storage.objectViewer"

  member =
    "serviceAccount:${google_service_account.etl_sa.email}"

}

###############################################################################
# D1 - Staged / Enforced BigQuery Dataset
#
# Purpose:
# Stores validated student onboarding records after they pass
# Django Serializer + DCYN validation.
###############################################################################

resource "google_bigquery_dataset" "d1_staged_enforced" {

  dataset_id    = "d1_staged_enforced"
  friendly_name = "D1 Staged Enforced"

  description = "Schema validated analytics layer"

  location = var.region

  labels = {
    stage       = "d1-staged"
    environment = var.environment
    managed_by  = "terraform"
  }

  access {

    role = "OWNER"

    user_by_email = var.data_platform_admin_email

  }

  access {

    role = "READER"

    user_by_email = var.analytics_reader_email

  }

}

###############################################################################
# Student Onboarding Table
#
# This table stores ONLY validated records.
#
# Data entering this table has already passed:
#
# • Django Serializer Validation
# • DCYN Boolean Validation
# • Schema Validation
#
###############################################################################

resource "google_bigquery_table" "student_onboarding" {

  dataset_id = google_bigquery_dataset.d1_staged_enforced.dataset_id

  table_id = "student_onboarding"

  deletion_protection = true

  ###########################################################################
  # Partition table by ingestion date
  ###########################################################################

  time_partitioning {

    type  = "DAY"

    field = "ingested_at"

  }

  # Prevent accidental full table scans

  require_partition_filter = true

  ###########################################################################
  # Cluster table by region
  ###########################################################################

  clustering = [

    "region_code"

  ]

  ###########################################################################
  # Table Schema
  ###########################################################################

  schema = jsonencode([

    {
      name = "student_id"
      type = "STRING"
      mode = "REQUIRED"
    },

    {
      name = "guardian_email"
      type = "STRING"
      mode = "REQUIRED"
    },

    {
      name = "diagnosed_learning_difficulty"
      type = "BOOLEAN"
      mode = "REQUIRED"
    },

    {
      name = "requires_one_on_one_support"
      type = "BOOLEAN"
      mode = "REQUIRED"
    },

    {
      name = "consent_data_processing"
      type = "BOOLEAN"
      mode = "REQUIRED"
    },

    {
      name = "region_code"
      type = "STRING"
      mode = "REQUIRED"
    },

    {
      name = "ingested_at"
      type = "TIMESTAMP"
      mode = "REQUIRED"
    }

  ])

}

###############################################################################
# Analyst Region Mapping Table
#
# Maps each analyst to the region they are allowed to access.
#
# Example:
#
# analyst@company.com → IN-TS
#
###############################################################################

resource "google_bigquery_table" "analyst_region_map" {

  dataset_id = google_bigquery_dataset.d1_staged_enforced.dataset_id

  table_id = "analyst_region_map"

  schema = jsonencode([

    {
      name = "analyst_email"
      type = "STRING"
      mode = "REQUIRED"
    },

    {
      name = "region_code"
      type = "STRING"
      mode = "REQUIRED"
    }

  ])

}

###############################################################################
# Row Level Security
#
# Analysts can only view students belonging to their assigned region.
###############################################################################

resource "google_bigquery_row_access_policy" "region_scoped_access" {

  project = var.project_id

  dataset_id = google_bigquery_dataset.d1_staged_enforced.dataset_id

  table_id = google_bigquery_table.student_onboarding.table_id

  row_access_policy_id = "region_scoped_access"

  filter_predicate = <<EOF
region_code IN (
  SELECT region_code
  FROM `${var.project_id}.${google_bigquery_dataset.d1_staged_enforced.dataset_id}.analyst_region_map`
  WHERE analyst_email = SESSION_USER()
)
EOF

  grantees = [

    "user:${var.analytics_reader_email}"

  ]

}

