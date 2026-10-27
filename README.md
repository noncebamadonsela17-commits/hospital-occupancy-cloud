# Hospital Occupancy Cloud Landing Zone

**Author:** Nonceba Mdonsela  
**Type:** Cloud engineering — IaC, object storage, queue, IAM, monitoring, cost guardrail

A small AWS landing zone for the **bed occupancy** pipeline. Clinics upload encounter CSVs when they have power and network. The cloud side buffers files, processes them without an always-on VM, and alerts on failure and spend.

This repo is the **cloud** half. The data-engineering pipeline lives in `bed-occupancy-pipeline`. Bronze CSVs use the same columns: `encounter_id`, `patient_id`, `department`, `admission_date`, `discharge_date`, `encounter_type`.

S3 and SQS keep the file if the clinic drops offline. Lambda validates at the door — no 24/7 EC2. IAM is split into upload, process, and audit. A $10 budget and CloudWatch alarms (Lambda errors, DLQ) keep a student account honest. After a demo, destroy the stack.

---

## Problem

A clinic cannot assume 24/7 connectivity (load-shedding, poor network). A single EC2 that must be online when they upload will miss files. The landing zone must **accept files when they arrive** and **retry** when the clinic is back.

## What this builds

| Piece | Role |
|--------|------|
| S3 bucket | Bronze landing zone (versioned CSVs) |
| SQS queue | Buffer so ingest is not lost if processing is slow |
| IAM roles | Least privilege: upload vs process vs read audit |
| Lambda (or scheduled task) | Validate CSV / log success — no 24/7 server |
| CloudWatch alarm | Failed processing is visible |
| AWS Budget | Student account does not silently burn money |
| Terraform | Everything above is code, not console clicking |

Region default: **af-south-1** (Cape Town).

## Layout

```
hospital-occupancy-cloud/
├── terraform/          # Infrastructure as code
├── scripts/            # Clinic upload with retries
├── lambda/             # Object-created handler (later)
└── docs/               # Architecture and runbook
```

## Documentation

| Document | Description |
|----------|-------------|
| [docs/runbook.md](docs/runbook.md) | Apply, clinic upload, failure drill, destroy |
| [docs/architecture.md](docs/architecture.md) | Clinic → S3 → SQS → Lambda |

## Not in v1

Kubernetes, Kafka, multi-region, Streamlit in the cloud.

## Local companion

Full occupancy pipeline copy on this PC:

`/home/wethinkcode_/Music/bed-occupancy-pipeline-full-copy`

Original working copy:

`/home/wethinkcode_/Music/bed-occupancy-pipeline`
