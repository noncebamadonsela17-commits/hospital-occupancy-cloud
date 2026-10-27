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

## End-to-end demo

One recorded pass with `bed-occupancy-pipeline` bronze `encounters.csv`.

1. `terraform apply` in `af-south-1`. Note `bronze_bucket` and `ingest_queue_url`.
2. Upload `encounters.csv` to `bronze/encounters.csv` with `scripts/retry_upload.py`.
3. Screenshot or note:
   - S3 object under `bronze/`
   - Audit log `logs/<date>/encounters.csv.json` with `"valid": true`
   - CloudWatch alarms (should be OK)
   - AWS Budget `hosp-occ-monthly` ($10)
4. Optional: upload `tests/fixtures/poison.csv`, show DLQ + alarms, then purge.

The clinic can disconnect after step 2. Processing does not need their laptop.

---

## Destroy and leftover-resource checklist

Monthly cap is `$10` (`var.budget_limit_usd`). Do not leave the stack up after a demo.

```bash
cd ~/Music/hospital-occupancy-cloud/terraform
terraform destroy
```

If destroy fails on a non-empty bucket:

```bash
aws s3 rm "s3://$(terraform output -raw bronze_bucket)" --recursive
terraform destroy
```

Then confirm in the console (and billing) that these are gone:

- [ ] S3 bronze bucket (including versions and `logs/`)
- [ ] SQS ingest queue and `hosp-occ-ingest-dlq`
- [ ] Lambda `hosp-occ-validator`
- [ ] Log group `/aws/lambda/hosp-occ-validator` (delete by hand if Terraform left it)
- [ ] Alarms `hosp-occ-validator-errors` and `hosp-occ-ingest-dlq-not-empty`
- [ ] IAM users `hosp-occ-uploader` and `hosp-occ-auditor`, role `hosp-occ-processor`
- [ ] Budget `hosp-occ-monthly` (optional to keep; it does not bill by itself)

v1 is done when the path above works **and** spend returns to ~$0.
