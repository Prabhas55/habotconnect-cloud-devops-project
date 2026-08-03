# HabotConnect Hiring Project — Junior Cloud & DevOps Engineer (GCP / Django / React)

**Full Name:** Prabhas Nalajala

**Email:** nalajaprabhas@gmail.com

**Submission Date:** 3 August 2026

---

## Folder Layout

```
habotconnect-project/
├── README.md                          # this file
├── SLIDE_OUTLINE.md                   # 15-slide presentation plan
├── HabotConnect_Hiring_Project.pptx   # the submitted deck
├── .gitignore
├── .gitleaks.toml                     # secret-scan rules (Task 2)
├── .github/
│   └── workflows/
│       └── build-gate.yml             # Task 2: Poka-Yoke fail-closed CI/CD gate
├── terraform/                         # Task 1: IaC
│   ├── main.tf                        # D0 GCS bucket + D1 BigQuery dataset, IAM, RLS
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example       # sample values, no real project data
└── django/                            # Task 3: Schema validation
    ├── dcyn.py                        # strict Yes/No validation library
    ├── models.py                      # StudentOnboarding model
    └── serializers.py                 # DRF serializer + DCYNField + exact limits
```

**Note:** `.github/workflows/` is kept at the repo root — this is a GitHub Actions requirement, not a style choice. GitHub only auto-detects workflow files at that exact path.

## Task Summary

**Task 1 — Terraform Secure Staging Provisioning**
- `D0 Raw Landing`: GCS bucket, uniform bucket-level access, CMEK (90-day rotation), versioning, 30-day lifecycle delete rule.
- IAM: ingestion service account is granted `storage.objectCreator` scoped by condition to `incoming/` only — cannot read, list, or delete.
- `D1 Staged/Enforced`: BigQuery dataset with a `student_onboarding` table and a row-access policy that scopes each analyst to their assigned region via an `analyst_region_map` lookup table.

**Task 2 — Poka-Yoke Build Gate**
- Four jobs: `lint`, `secret-scan`, `build`, `deploy`.
- `build` and `deploy` declare `needs: [lint, secret-scan]` (and `needs: [build]` for deploy) — GitHub Actions will not run them if either gate job fails. This is the fail-closed mechanism, not a soft warning.
- Gitleaks scans every push/PR for hardcoded secrets using `.gitleaks.toml`; flake8/black/ESLint enforce formatting and lint rules.

**Task 3 — Schema Mapping & DCYN Validation**
- `dcyn.py`: converts raw Yes/No-ish input into a strict boolean via a fixed whitelist (`yes/y/true/1`, `no/n/false/0`). Anything else — blank, null, "maybe" — raises `DCYNError`. No silent guessing.
- `serializers.py`: `StudentOnboardingSerializer` wraps every DCYN field with a custom `DCYNField`, and enforces exact limits on every other field (name length/charset, age range 3-18, phone regex, region code format, mandatory explicit consent).

## How to Verify Locally

```bash
# DCYN library — pure Python, no dependencies
python3 django/dcyn.py

# Terraform — requires terraform CLI + GCP credentials, not run here
cd terraform && terraform init && terraform validate

# CI/CD — push to a test branch on GitHub to see the gate run live
```

## Assumptions Made (no resource person available)

- `backend/` and `frontend/` directory names in the CI/CD workflow are assumed based on the JD's Django + React stack; adjust paths to match the real repo structure.
- BigQuery Row-Level Security uses the native `google_bigquery_row_access_policy` resource (Terraform google provider ≥ 5.x) rather than authorized views, since it composes more cleanly with IAM.
- Student age range (3-18) was inferred from the LSA platform's target audience (children with learning difficulties) — adjust if the real business rule differs.


