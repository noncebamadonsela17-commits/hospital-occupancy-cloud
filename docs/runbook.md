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

## Later

How to read logs, budget at 80%, and `terraform destroy` land in the next commits.
