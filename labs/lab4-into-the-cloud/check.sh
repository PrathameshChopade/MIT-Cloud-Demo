#!/usr/bin/env bash
# Three posture checks against the LIVE account, the kind of thing AWS Security
# Hub, AWS Config or Prowler run continuously. Exit code 1 if any check fails,
# 2 if the checks could not run.
set -u
cd "$(dirname "$0")/terraform"
export AWS_PAGER=""

# Stop with a clear message if a command ran out of time (exit code 124).
stop_if_timed_out() {
  if [ "$1" -eq 124 ]; then
    echo "  No answer within 30 seconds. Your AWS sign-in has probably expired:" >&2
    echo "  run 'aws login', then: eval \"\$(aws configure export-credentials --format env)\"" >&2
    exit 2
  fi
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
  echo "  Could not read the Terraform outputs. Run 'terraform apply' in labs/lab4-into-the-cloud/terraform first." >&2
  exit 2
fi
failed=0

echo "Check 1: no SSH open to the internet on $sg"
open=$(timeout 30 aws ec2 describe-security-groups --region "$region" --group-ids "$sg" \
  --filters Name=ip-permission.from-port,Values=22 Name=ip-permission.cidr,Values=0.0.0.0/0 \
  --query "SecurityGroups[].GroupId" --output text 2>&1); rc=$?
stop_if_timed_out "$rc"
if [ "$rc" -ne 0 ]; then
  echo "  ERROR  $open"
  failed=1
elif [ -n "$open" ]; then
  echo "  FAIL  port 22 is open to 0.0.0.0/0"
  failed=1
else
  echo "  PASS"
fi

echo "Check 2: Block Public Access fully on for $bucket"
settings=$(timeout 30 aws s3api get-public-access-block --region "$region" --bucket "$bucket" \
  --query "PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]" \
  --output text 2> /dev/null); rc=$?
stop_if_timed_out "$rc"
if [ "$(echo $settings)" = "True True True True" ]; then
  echo "  PASS"
else
  echo "  FAIL  Block Public Access is missing or partly off"
  failed=1
fi

echo "Check 3: the bucket policy does not make $bucket public"
public=$(timeout 30 aws s3api get-bucket-policy-status --region "$region" --bucket "$bucket" \
  --query "PolicyStatus.IsPublic" --output text 2> /dev/null); rc=$?
stop_if_timed_out "$rc"
if [ "$public" = "True" ]; then
  echo "  FAIL  the bucket policy lets anyone read the files"
  failed=1
else
  echo "  PASS"
fi

exit "$failed"
