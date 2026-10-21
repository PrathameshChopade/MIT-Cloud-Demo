#!/usr/bin/env bash
# Simulates a colleague "quickly fixing something" directly in the AWS account,
# bypassing the code, the scanners and the pipeline:
#   1. opens SSH (port 22) to the whole internet
#   2. removes the bucket's Block Public Access
#   3. replaces the bucket policy with one that lets ANYONE read its files
#
# After change 3 the demo file is readable by anyone with the link. It holds
# fake data only. Run `terraform apply` straight after the demo to undo it.
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

echo "Change 3: making every file in $bucket readable by anyone"
policy=$(printf '{"Version":"2012-10-17","Statement":[{"Sid":"PublicRead","Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::%s/*"}]}' "$bucket")
if ! aws s3api put-bucket-policy --region "$region" --bucket "$bucket" --policy "$policy"; then
  echo >&2
  echo "AWS refused the public policy: account-level Block Public Access is probably on." >&2
  echo "That account guardrail just stopped the leak. See FACILITATOR.md (Lab 4) for options." >&2
  exit 1
fi

url="https://$bucket.s3.$region.amazonaws.com/customers.csv"
echo
echo "The file is now public. Anyone with this link can read it:"
echo
echo "  $url"
echo
if command -v qrencode > /dev/null; then
  qrencode -t ANSIUTF8 -m 2 "$url"
fi
echo "Undo it with: terraform apply   (the same link then returns Access Denied)"
