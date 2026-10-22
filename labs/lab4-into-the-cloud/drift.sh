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
export AWS_PAGER=""

# Runs an AWS CLI command with a time limit, so an expired sign-in shows up as
# a clear message instead of a hang.
run_aws() {
  local rc=0
  timeout 30 aws "$@" || rc=$?
  if [ "$rc" -eq 124 ]; then
    echo "No answer from AWS within 30 seconds. Your sign-in has probably expired:" >&2
    echo "run 'aws login --profile default', then: export AWS_PROFILE=terraform" >&2
    exit 2
  fi
  return "$rc"
}

echo "Reading the deployed resources from Terraform..."
# Read the outputs straight from the state file: one quick read instead of
# three `terraform output` calls, which take about 15 seconds each on /mnt/c.
outputs=$(python3 -c '
import json
out = json.load(open("terraform.tfstate"))["outputs"]
print(out["region"]["value"], out["bucket_name"]["value"], out["security_group_id"]["value"])
' 2> /dev/null) || outputs=""
read -r region bucket sg <<< "$outputs"
if [ -z "${sg:-}" ]; then
  echo "Could not read the Terraform outputs. Run 'terraform apply' in labs/lab4-into-the-cloud/terraform first." >&2
  exit 2
fi

echo "Change 1: opening SSH (port 22) to the whole internet on $sg"
run_aws ec2 authorize-security-group-ingress --region "$region" \
  --group-id "$sg" --protocol tcp --port 22 --cidr 0.0.0.0/0 > /dev/null 2>&1 \
  || echo "  (already open from an earlier run)"

echo "Change 2: removing Block Public Access from bucket $bucket"
run_aws s3api delete-public-access-block --region "$region" --bucket "$bucket" 2> /dev/null \
  || echo "  (already removed from an earlier run)"

echo "Change 3: making every file in $bucket readable by anyone"
policy=$(printf '{"Version":"2012-10-17","Statement":[{"Sid":"PublicRead","Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::%s/*"}]}' "$bucket")
if ! run_aws s3api put-bucket-policy --region "$region" --bucket "$bucket" --policy "$policy"; then
  echo >&2
  echo "AWS refused the public policy: account-level Block Public Access is probably on." >&2
  echo "That account guardrail just stopped the leak. See FACILITATOR.md (Lab 4) for options." >&2
  exit 1
fi

url="https://$bucket.s3.$region.amazonaws.com/customers.html"
echo
echo "The file is now public. Anyone with this link can read it:"
echo
echo "  $url"
echo
if command -v qrencode > /dev/null; then
  qrencode -t ANSIUTF8 -m 2 "$url"
fi
echo "Undo it with: terraform apply   (the same link then returns Access Denied)"
