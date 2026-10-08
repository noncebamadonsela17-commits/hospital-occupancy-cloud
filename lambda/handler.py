"""Lambda entry: SQS (S3 object-created) → validate bronze CSV."""
from __future__ import annotations

import json
import logging
import urllib.parse

import boto3

from validate import validate_csv

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")


def lambda_handler(event, context):
    for record in event.get("Records", []):
        body = record.get("body") or "{}"
        payload = json.loads(body)
        for s3_record in payload.get("Records", []):
            bucket = s3_record["s3"]["bucket"]["name"]
            key = urllib.parse.unquote_plus(s3_record["s3"]["object"]["key"])
            _validate_object(bucket, key)
    return {"ok": True}


def _validate_object(bucket: str, key: str) -> None:
    logger.info("Validating s3://%s/%s", bucket, key)
    obj = s3.get_object(Bucket=bucket, Key=key)
    text = obj["Body"].read().decode("utf-8")
    errors = validate_csv(text)
    if errors:
        logger.error("Invalid CSV s3://%s/%s: %s", bucket, key, errors)
        raise ValueError(f"invalid CSV {key}: {errors}")
    logger.info("Valid CSV s3://%s/%s", bucket, key)
