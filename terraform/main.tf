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
# D0 - Raw Landing (Google Cloud Storage)
#
# Purpose:
# Secure landing zone for raw student onboarding JSON payloads before
# schema validation and downstream processing.
###############################################################################

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

  # Rotate encryption key every 90 days
  rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }

}

###############################################################################
# D0 Raw Landing Bucket
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
  # Versioning
  ###########################################################################

  versioning {
    enabled = true
  }

  ###########################################################################
  # Lifecycle Management
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
# Least Privilege Principle
#
# The ingestion service account can ONLY upload new objects under
# the incoming/ folder.
#
# It CANNOT:
#
# - Read existing files
# - Delete files
# - List bucket contents
#
###############################################################################

resource "google_storage_bucket_iam_member" "d0_writer" {

  bucket = google_storage_bucket.d0_raw_landing.name

  role = "roles/storage.objectCreator"

  member = "serviceAccount:${var.ingestion_service_account}"

  condition {

    title = "write_only_incoming"

    description = "Only upload objects under incoming/"

    expression =
    "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.d0_raw_landing.name}/objects/incoming/\")"

  }

}

###############################################################################
# ETL Read Access
#
# ETL can ONLY read raw files.
# It cannot modify or delete them.
###############################################################################

resource "google_storage_bucket_iam_member" "d0_reader" {

  bucket = google_storage_bucket.d0_raw_landing.name

  role = "roles/storage.objectViewer"

  member = "serviceAccount:${var.etl_service_account}"

}


###############################################################################
# D1 - Staged / Enforced BigQuery Dataset
#
# Purpose:
# Stores validated student onboarding data after schema validation
# performed by the Django REST Framework serializer and DCYN library.
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

  ###########################################################################
  # Dataset Access
  ###########################################################################

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
# Only validated records are stored here.
#
# The Django Serializer guarantees:
#
# • Correct data types
# • Valid phone numbers
# • Age limits
# • DCYN Yes/No conversion
#
###############################################################################

resource "google_bigquery_table" "student_onboarding" {

  dataset_id = google_bigquery_dataset.d1_staged_enforced.dataset_id

  table_id = "student_onboarding"

  deletion_protection = true

  ###########################################################################
  # Partition Table
  #
  # Improves performance when querying by ingestion date.
  ###########################################################################

  time_partitioning {

    type = "DAY"

    field = "ingested_at"

  }

  ###########################################################################
  # Cluster by Region
  #
  # Most analyst queries filter by region.
  ###########################################################################

  clustering = [

    "region_code"

  ]

  ###########################################################################
  # Schema
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
# Analyst Region Mapping
#
# Maps analysts to the regions they are permitted to access.
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
# Row-Level Security (RLS)
#
# Purpose:
# Analysts should only view student records belonging to the regions
# assigned to them.
#
# Example:
#
# analyst@company.com  →  IN-TS
#
# When analyst@company.com queries the student_onboarding table,
# only records where region_code = IN-TS are returned.
#
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
