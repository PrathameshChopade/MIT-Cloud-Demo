#!/usr/bin/env bash
# Two posture checks against the LIVE account, the kind of thing AWS Security
# Hub, AWS Config or Prowler run continuously. Exit code 1 if any check fails.
set -u
cd "$(dirname "$0")/terraform"

region=$(terraform output -raw region)
bucket=$(terraform output -raw bucket_name)
sg=$(terraform output -raw security_group_id)
failed=0

echo "Check 1: no SSH open to the internet on $sg"
open=$(aws ec2 describe-security-groups --region "$region" --group-ids "$sg" \
  --filters Name=ip-permission.from-port,Values=22 Name=ip-permission.cidr,Values=0.0.0.0/0 \
  --query "SecurityGroups[].GroupId" --output text)
if [ -n "$open" ]; then
  echo "  FAIL  port 22 is open to 0.0.0.0/0"
  failed=1
else
  echo "  PASS"
fi

echo "Check 2: Block Public Access fully on for $bucket"
settings=$(aws s3api get-public-access-block --region "$region" --bucket "$bucket" \
  --query "PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]" \
  --output text 2> /dev/null || true)
if [ "$(echo $settings)" = "True True True True" ]; then
  echo "  PASS"
else
  echo "  FAIL  Block Public Access is missing or partly off"
  failed=1
fi

exit "$failed"
