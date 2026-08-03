# Presentation Outline — Max 15 Slides
(Build this in Google Slides / PowerPoint. Keep each slide to one idea + one diagram/screenshot.)

1. **Title** — Your full name, contact info, role applied for, date.
2. **Scenario Recap** — The staging incident: exposed credentials + schema mismatch (2-3 lines, your own words).
3. **Architecture Overview** — One diagram: D0 (GCS raw landing) → ETL/validation → D1 (BigQuery staged).
4. **Task 1: IaC Design Decisions** — Why GCS + KMS encryption + versioning for D0.
5. **Task 1: IAM Least Privilege** — The conditional IAM binding (ingestion SA write-only to `/incoming/`).
6. **Task 1: BigQuery RLS** — How `analyst_region_map` + row access policy scopes analyst visibility.
7. **Task 2: Pipeline Overview** — Diagram of the 4 jobs: lint → secret-scan → build → deploy, with `needs:` gating.
8. **Task 2: Fail-Closed Proof** — Screenshot/description of a run where a lint or secret-scan failure blocks `build`/`deploy` entirely.
9. **Task 2: Secret Detection** — Show the Gitleaks rule catching a hardcoded key (use a fake test string, never a real one).
10. **Task 3: DCYN Library** — The problem (ambiguous Yes/No input) and the fix (strict whitelist, no fallback guessing).
11. **Task 3: Serializer Validation** — Walk through 2-3 field limits (age range, phone regex, mandatory consent).
12. **Task 3: Rejected Payload Example** — Show an invalid payload and the exact validation errors it produces.
13. **Trade-offs & Assumptions** — What you assumed given no company resource person was available, and why.
14. **What You'd Do With More Time** — e.g., CMEK rotation automation, Terraform remote state, integration tests.
15. **Closing / Links** — Links to your code repo/folder, thank you, contact info repeated.

**Tip:** Every slide should point back to a specific file in this folder so the panel can trace claims to code.
