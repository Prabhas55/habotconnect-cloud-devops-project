output "d0_bucket_name" {

  description = "Raw Landing Bucket"

  value = google_storage_bucket.d0_raw_landing.name

}

output "d1_dataset" {

  description = "Validated BigQuery Dataset"

  value = google_bigquery_dataset.d1_staged_enforced.dataset_id

}

output "student_table" {

  description = "Student Onboarding Table"

  value = google_bigquery_table.student_onboarding.table_id

}

output "analyst_mapping_table" {

  description = "Analyst Region Mapping Table"

  value = google_bigquery_table.analyst_region_map.table_id

}

output "kms_key" {

  description = "Customer Managed Encryption Key"

  value = google_kms_crypto_key.raw_landing_key.id

}
output "ingestion_service_account_email" {
  value = google_service_account.ingestion_sa.email
}

output "etl_service_account_email" {
  value = google_service_account.etl_sa.email
}
