# Configuration for the order export service.
# Secrets come from the environment (set by the platform or a secrets manager),
# never from the repository. There are no AWS keys here at all: boto3 picks up
# credentials from the instance's IAM role, or from the environment locally.
import os

AWS_REGION = os.environ.get("AWS_REGION", "eu-west-1")

DB_HOST = os.environ.get("DB_HOST", "orders-db.internal")
DB_USER = os.environ.get("DB_USER", "export_svc")
DB_PASSWORD = os.environ["DB_PASSWORD"]
