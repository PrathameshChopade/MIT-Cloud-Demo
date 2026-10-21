"""Uploads the daily order export to S3."""
from pathlib import Path

import boto3

from config import AWS_REGION

BUCKET = "acme-customer-reports"


def upload(path):
    # No keys passed in: boto3 uses the IAM role (in the cloud) or the
    # developer's own short-lived credentials (locally).
    s3 = boto3.client("s3", region_name=AWS_REGION)
    s3.upload_file(path, BUCKET, Path(path).name)


if __name__ == "__main__":
    upload("orders.csv")
