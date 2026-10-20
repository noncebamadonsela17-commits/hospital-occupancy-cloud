# Runbook — hospital occupancy cloud

Region: `af-south-1` (Cape Town). Budget API: `us-east-1`.

## Apply

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — set budget_notification_email to your address
terraform init
terraform plan
terraform apply
terraform output
```

Record: `bronze_bucket`, `ingest_queue_url`, `aws_region`.

Do not commit `terraform.tfvars`.

## Clinic upload

```bash
pip install boto3
export BRONZE_BUCKET="$(terraform -chdir=terraform output -raw bronze_bucket)"
python3 scripts/retry_upload.py /path/to/bed-occupancy-pipeline/data/bronze/encounters.csv \
  --bucket "$BRONZE_BUCKET" \
  --key bronze/encounters.csv
```

Expect: object in S3 under `bronze/` and one message on the ingest queue.

## Failure drill (poison CSV)

Use this when you need to prove alarms work. Do not leave the DLQ dirty afterwards.

1. Upload the broken fixture:

```bash
export BRONZE_BUCKET="$(terraform -chdir=terraform output -raw bronze_bucket)"
python3 scripts/retry_upload.py tests/fixtures/poison.csv \
  --bucket "$BRONZE_BUCKET" \
  --key bronze/poison.csv
```

2. Confirm four signals:
   - Lambda **Errors** on `hosp-occ-validator`
   - SQS retries on the ingest queue (`maxReceiveCount = 5`)
   - A message on `hosp-occ-ingest-dlq`
   - CloudWatch alarms `hosp-occ-validator-errors` and `hosp-occ-ingest-dlq-not-empty` in **ALARM**

3. Clean up:
   - Purge the DLQ in the console (or AWS CLI)
   - Leave the bronze object (versioning keeps history)
   - Wait until both alarms return to OK

## How to read logs

Lambda writes to CloudWatch Logs log group:

`/aws/lambda/hosp-occ-validator`

Audit JSON also lands in S3: `s3://<bronze_bucket>/logs/<date>/<file>.json`.

### One Logs Insights query

Log group: `/aws/lambda/hosp-occ-validator`

```
fields @timestamp, @message
| filter @message like /bronze/
| sort @timestamp desc
| limit 50
```

To search for one object, replace `bronze/` with the key, for example `bronze/encounters.csv`.

## What to do if an alarm fires

**DLQ not empty** (`hosp-occ-ingest-dlq-not-empty`): a clinic file failed validation five times. Open the DLQ message, read the S3 key, inspect `logs/<date>/` for `"valid": false`, fix or replace the CSV, re-upload, then purge the DLQ.

**Lambda errors** (`hosp-occ-validator-errors`): open the log group above. If the CSV is bad, that is expected during a drill. If a good CSV fails, check IAM (`GetObject` on `bronze/`, `PutObject` on `logs/`) and the event source mapping.

**Budget at 80%** (`hosp-occ-monthly`): stop unused applies. Confirm region is `af-south-1`. After a demo, run `terraform destroy` (full destroy checklist is the last commit). Do not leave Lambda log groups if you meant to tear everything down.
