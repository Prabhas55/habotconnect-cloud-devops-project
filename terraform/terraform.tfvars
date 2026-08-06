###############################################################################
# GCP Project
###############################################################################

project_id = "habotconnect-staging"

region = "asia-south1"

environment = "staging"

###############################################################################
# Service Accounts
###############################################################################

ingestion_service_account = "student-ingestion-sa"

etl_service_account = "student-etl-sa"

###############################################################################
# BigQuery Users
###############################################################################

data_platform_admin_email = "admin@habotconnect.com"

analytics_reader_email = "analyst@habotconnect.com"
