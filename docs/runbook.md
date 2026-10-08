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

## Later

Failure drill, alarms, and `terraform destroy` land in Iteration 3–4.
