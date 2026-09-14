#!/usr/bin/env python3
"""Upload a bronze CSV to S3 with retries (clinic / load-shedding)."""
from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

try:
    import boto3
    from botocore.exceptions import BotoCoreError, ClientError
except ImportError:
    print("Install: pip install boto3", file=sys.stderr)
    sys.exit(1)


def upload_with_retry(bucket: str, key: str, path: Path, attempts: int = 6) -> None:
    client = boto3.client("s3")
    delay = 2
    last_error: Exception | None = None
    for i in range(1, attempts + 1):
        try:
            client.upload_file(str(path), bucket, key)
            print(f"Uploaded s3://{bucket}/{key} on attempt {i}")
            return
        except (BotoCoreError, ClientError, OSError) as exc:
            last_error = exc
            print(f"Attempt {i}/{attempts} failed: {exc}", file=sys.stderr)
            time.sleep(delay)
            delay = min(delay * 2, 60)
    raise SystemExit(f"Upload failed after {attempts} attempts: {last_error}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Retrying S3 upload for occupancy CSVs")
    parser.add_argument("file", type=Path, help="Local encounters.csv")
    parser.add_argument("--bucket", default=os.environ.get("BRONZE_BUCKET"), help="S3 bucket name")
    parser.add_argument("--key", default=None, help="Object key (default: bronze/encounters.csv)")
    args = parser.parse_args()
    if not args.bucket:
        raise SystemExit("Set --bucket or BRONZE_BUCKET")
    if not args.file.is_file():
        raise SystemExit(f"File not found: {args.file}")
    key = args.key or f"bronze/{args.file.name}"
    upload_with_retry(args.bucket, key, args.file)


if __name__ == "__main__":
    main()
