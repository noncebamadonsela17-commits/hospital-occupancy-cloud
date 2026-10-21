# Runbook — hospital occupancy cloud

Operator guide for apply, clinic upload, failure, and destroy. Pop!_OS / Ubuntu.

Region: **`af-south-1`** (Cape Town). AWS Budgets API: **`us-east-1`**.

---

## Prerequisites

- AWS account with permission to create S3, SQS, IAM, Lambda, CloudWatch, and Budgets
- AWS CLI configured (`aws sts get-caller-identity` works)
- Terraform >= 1.5
- Python 3.11+ and `pip install boto3`
- This repo cloned; `bed-occupancy-pipeline` bronze `encounters.csv` for the happy path

```bash
cd ~/Music/hospital-occupancy-cloud
aws sts get-caller-identity
terraform -chdir=terraform version
```

---

## Apply

```bash
cd ~/Music/hospital-occupancy-cloud/terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

Set `budget_notification_email` to your address. Do **not** commit `terraform.tfvars`.

```bash
terraform init
terraform plan
terraform apply
terraform output
```

Record: `bronze_bucket`, `ingest_queue_url`, `aws_region`, `validator_function_name`.

---

## Expected S3 keys

| Key | What it is |
|-----|------------|
| `bronze/encounters.csv` | Clinic happy-path upload |
| `bronze/poison.csv` | Failure-drill upload |
| `logs/<YYYY-MM-DD>/<file>.json` | Validation audit (`valid`, `errors`, `timestamp`) |

Uploads must use the `bronze/` prefix or S3 will not notify SQS.

---

## Clinic upload

```bash
cd ~/Music/hospital-occupancy-cloud
pip install boto3
export BRONZE_BUCKET="$(terraform -chdir=terraform output -raw bronze_bucket)"
python3 scripts/retry_upload.py /path/to/bed-occupancy-pipeline/data/bronze/encounters.csv \
  --bucket "$BRONZE_BUCKET" \
  --key bronze/encounters.csv
```

Expect:

1. Object at `s3://$BRONZE_BUCKET/bronze/encounters.csv`
2. SQS ingest message (or Lambda already processed it)
3. Audit object under `logs/<date>/encounters.csv.json` with `"valid": true`

The clinic laptop can go offline after a successful PUT. S3 and SQS keep the file.

---

## Failure drill (poison CSV)

Do not leave the DLQ dirty afterwards.

```bash
export BRONZE_BUCKET="$(terraform -chdir=terraform output -raw bronze_bucket)"
python3 scripts/retry_upload.py tests/fixtures/poison.csv \
  --bucket "$BRONZE_BUCKET" \
  --key bronze/poison.csv
```

Confirm:

- Lambda **Errors** on `hosp-occ-validator`
- SQS retries (`maxReceiveCount = 5`)
- A message on `hosp-occ-ingest-dlq`
- Alarms `hosp-occ-validator-errors` and `hosp-occ-ingest-dlq-not-empty` in **ALARM**

Clean up: purge the DLQ, leave the bronze object (versioning keeps history), wait for alarms to return to OK.

---

## How to read logs

Log group: `/aws/lambda/hosp-occ-validator`

```
fields @timestamp, @message
| filter @message like /bronze/
| sort @timestamp desc
| limit 50
```

Replace `bronze/` with a key such as `bronze/encounters.csv` to filter one file.

---

## What to do if an alarm fires

**DLQ not empty** (`hosp-occ-ingest-dlq-not-empty`): a file failed five times. Read the S3 key from the DLQ, open `logs/<date>/` for `"valid": false`, fix or replace the CSV, re-upload, purge the DLQ.

**Lambda errors** (`hosp-occ-validator-errors`): open the log group. Bad CSV is expected in a drill. A good CSV failing usually means IAM or the event source mapping.

**Budget at 80%** (`hosp-occ-monthly`): stop unused applies. Stay in `af-south-1`. Destroy when the demo is done.

---

## Destroy and cost

Monthly cap is `$10` (`var.budget_limit_usd`). Do not leave the stack up after a demo.

```bash
cd ~/Music/hospital-occupancy-cloud/terraform
terraform destroy
```

After destroy, in the console check:

- S3 bucket gone (empty it first if Terraform cannot delete objects)
- SQS queues gone
- Lambda `hosp-occ-validator` gone
- Log group `/aws/lambda/hosp-occ-validator` gone (delete by hand if it lingered)
- Alarms gone
- Budget can stay (it costs nothing) or be removed with destroy

A fuller demo + leftover-resource checklist is the last commit.
