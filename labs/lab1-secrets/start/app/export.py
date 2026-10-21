"""Uploads the daily order export to S3."""
from pathlib import Path

import boto3

from config import AWS_ACCESS_KEY_ID, AWS_REGION, AWS_SECRET_ACCESS_KEY

BUCKET = "acme-customer-reports"


def upload(path):
    s3 = boto3.client(
        "s3",
        region_name=AWS_REGION,
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY,
    )
    s3.upload_file(path, BUCKET, Path(path).name)


if __name__ == "__main__":
    upload("orders.csv")
