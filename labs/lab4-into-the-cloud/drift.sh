#!/usr/bin/env bash
# Simulates a colleague "quickly fixing something" directly in the AWS account,
# bypassing the code, the scanners and the pipeline.
#
# It does NOT make the bucket public: it only removes the bucket's protection,
# which is enough to show the drift without exposing anything.
set -eu
cd "$(dirname "$0")/terraform"

region=$(terraform output -raw region)
bucket=$(terraform output -raw bucket_name)
sg=$(terraform output -raw security_group_id)

echo "Change 1: opening SSH (port 22) to the whole internet on $sg"
aws ec2 authorize-security-group-ingress --region "$region" \
  --group-id "$sg" --protocol tcp --port 22 --cidr 0.0.0.0/0 > /dev/null

echo "Change 2: removing Block Public Access from bucket $bucket"
aws s3api delete-public-access-block --region "$region" --bucket "$bucket"

echo "Done. The code is unchanged, so every scanner would still pass."
