terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ---------------------------------------------------------------------------
# D0 — Raw Landing Bucket (GCS)
# Purpose: durable, encrypted landing zone for unprocessed inbound payloads
# (e.g. student onboarding JSON) before schema validation.
# ---------------------------------------------------------------------------

resource "google_kms_key_ring" "raw_landing_ring" {
  name     = "d0-raw-landing-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "raw_landing_key" {
  name            = "d0-raw-landing-key"
  key_ring        = google_kms_key_ring.raw_landing_ring.id
  rotation_period = "7776000s" # 90 days
}

resource "google_storage_bucket" "d0_raw_landing" {
  name                        = "${var.project_id}-d0-raw-landing"
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  encryption {
    default_kms_key_name = google_kms_crypto_key.raw_landing_key.id
  }

  labels = {
    stage       = "d0-raw"
    environment = var.environment
    managed_by  = "terraform"
  }
}

# Least-privilege write access: ingestion SA may only PUT into /incoming/,
# never read, list, or delete. Poka-Yoke at the IAM layer — a compromised
# ingestion credential cannot exfiltrate or wipe existing raw data.
resource "google_storage_bucket_iam_member" "d0_writer" {
  bucket = google_storage_bucket.d0_raw_landing.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${var.ingestion_service_account}"

  condition {
    title       = "d0-write-only-incoming-prefix"
    description = "Ingestion SA may create objects only under incoming/, no read/list/delete"
    expression  = "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.d0_raw_landing.name}/objects/incoming/\")"
  }
}

resource "google_storage_bucket_iam_member" "d0_reader" {
  bucket = google_storage_bucket.d0_raw_landing.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.etl_service_account}"
}

# ---------------------------------------------------------------------------
# D1 — Staged / Enforced BigQuery dataset
# Purpose: schema-validated, RLS-protected analytics layer fed by the ETL
# job after DCYN/serializer validation (see django/serializers.py).
# ---------------------------------------------------------------------------

resource "google_bigquery_dataset" "d1_staged_enforced" {
  dataset_id   = "d1_staged_enforced"
  friendly_name = "D1 Staged Enforced"
  description  = "Schema-validated staging layer fed from D0 raw landing"
  location     = var.region

  labels = {
    stage       = "d1-staged"
    environment = var.environment
  }

  access {
    role          = "OWNER"
    user_by_email = var.data_platform_admin_email
  }

  access {
    role          = "READER"
    user_by_email = var.analytics_reader_email
  }
}

resource "google_bigquery_table" "student_onboarding" {
  dataset_id          = google_bigquery_dataset.d1_staged_enforced.dataset_id
  table_id            = "student_onboarding"
  deletion_protection = true

  schema = jsonencode([
    { name = "student_id", type = "STRING", mode = "REQUIRED" },
    { name = "guardian_email", type = "STRING", mode = "REQUIRED" },
    { name = "diagnosed_learning_difficulty", type = "BOOLEAN", mode = "REQUIRED" },
    { name = "requires_one_on_one_support", type = "BOOLEAN", mode = "REQUIRED" },
    { name = "consent_data_processing", type = "BOOLEAN", mode = "REQUIRED" },
    { name = "region_code", type = "STRING", mode = "REQUIRED" },
    { name = "ingested_at", type = "TIMESTAMP", mode = "REQUIRED" },
  ])
}

# Mapping table used by the row-access policy below: which analyst may
# see which region's rows. Keeps RLS logic data-driven, not hardcoded.
resource "google_bigquery_table" "analyst_region_map" {
  dataset_id = google_bigquery_dataset.d1_staged_enforced.dataset_id
  table_id   = "analyst_region_map"

  schema = jsonencode([
    { name = "analyst_email", type = "STRING", mode = "REQUIRED" },
    { name = "region_code", type = "STRING", mode = "REQUIRED" },
  ])
}

# Row-Level Security: an analyst querying student_onboarding only ever
# sees rows whose region_code matches their entry in analyst_region_map.
# Removes reliance on analysts manually filtering by region (Poka-Yoke
# at the data layer, not the honor system).
resource "google_bigquery_row_access_policy" "region_scoped_access" {
  project               = var.project_id
  dataset_id            = google_bigquery_dataset.d1_staged_enforced.dataset_id
  table_id              = google_bigquery_table.student_onboarding.table_id
  row_access_policy_id  = "region_scoped_access"

  filter_predicate = "region_code IN (SELECT region_code FROM `${var.project_id}.${google_bigquery_dataset.d1_staged_enforced.dataset_id}.analyst_region_map` WHERE analyst_email = SESSION_USER())"

  grantees = [
    "user:${var.analytics_reader_email}",
  ]
}
