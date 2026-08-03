output "d0_bucket_name" {
  description = "Name of the D0 raw landing GCS bucket"
  value       = google_storage_bucket.d0_raw_landing.name
}

output "d1_dataset_id" {
  description = "BigQuery dataset ID for the D1 staged/enforced layer"
  value       = google_bigquery_dataset.d1_staged_enforced.dataset_id
}

output "student_onboarding_table_fqn" {
  description = "Fully-qualified BigQuery table name for student_onboarding"
  value       = "${var.project_id}.${google_bigquery_dataset.d1_staged_enforced.dataset_id}.${google_bigquery_table.student_onboarding.table_id}"
}
