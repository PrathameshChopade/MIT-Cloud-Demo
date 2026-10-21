# Lab 4 — Into the cloud: deploy, drift and detect (15 min, facilitator demo)

**Goal:** finish the path to the cloud. The code passes its checks and is deployed to a real AWS account. Then someone changes the live cloud by hand, and every pre-deployment scanner still says "all good". This lab shows how that gap is closed.

**Covers:** storage (S3), networking (VPC and security groups), identity (IAM roles) and the shared responsibility model, on a real AWS account.

**Cost:** nothing meaningful. A bucket, a tiny file, a security group and an IAM role. No servers are launched, and step 6 removes everything.

**Where:** the facilitator's Ubuntu terminal, with Terraform and the AWS CLI installed and signed in (see FACILITATOR.md). The Checkov step runs in the toolbox.

```bash
cd labs/lab4-into-the-cloud/terraform
```

## 1. Gate, then deploy

Toolbox (the same must-fix list the CI gate uses in Lab 3):
```bash
checkov -d /workspace/labs/lab4-into-the-cloud/terraform --config-file /etc/secure-path/checkov-baseline.yaml
# expect: no failed checks
```

Ubuntu terminal:
```bash
aws sts get-caller-identity       # who am I? (account and role; never show keys)
terraform init
terraform plan                    # 7 resources to add: read them out
terraform apply                   # type "yes"
```

What now exists, and its cloud building block:

| Resource | Building block | Secure by default because |
|---|---|---|
| S3 bucket | Storage | All four Block Public Access settings on, encrypted, versioned |
| Security group in the default VPC | Networking | HTTPS only, no SSH |
| IAM role with an inline policy | Identity | Can only read and write files in that one bucket |

## 2. Check it from the outside

```bash
bucket=$(terraform output -raw bucket_name); region=$(terraform output -raw region)
printf 'id,name,email\n1,Asha Rao,asha@example.com\n' > customers.csv
aws s3 cp customers.csv "s3://$bucket/"

curl -s -o /dev/null -w "%{http_code}\n" "https://$bucket.s3.$region.amazonaws.com/customers.csv"
# expect: 403, the internet can't read it

url=$(aws s3 presign "s3://$bucket/customers.csv" --expires-in 120 --region "$region")
curl -s "$url"
# expect: the file contents. The link stops working after 2 minutes.
```

**Say:** sharing a file doesn't need a public bucket. A presigned link gives one person access to one file, for a short time.

## 3. Everything is green

```bash
bash ../check.sh                  # expect: PASS, PASS
```

## 4. Drift: a colleague "just fixes something" in the console

```bash
bash ../drift.sh                  # opens SSH to the world, removes the bucket's protection
bash ../check.sh                  # expect: FAIL, FAIL
```

**Say:** the code hasn't changed, so gitleaks, SonarQube and Checkov would all still pass. Pre-deployment scanners only see code. They can't see what people do in the live account.

## 5. Detect and fix

```bash
terraform plan
# expect: the extra SSH rule will be removed, and the Block Public Access setting re-created
terraform apply                   # puts the cloud back the way the code says
bash ../check.sh                  # expect: PASS, PASS
```

**Say:** two habits close the gap:
- **Infrastructure as code is the source of truth.** Changes go through code and review, and `terraform plan` shows any drift.
- **Continuous posture checks on the live account,** like `check.sh` but run all the time: AWS Security Hub, AWS Config or Prowler.

## 6. Shared responsibility, then clean up

| AWS secured | We decided |
|---|---|
| Data centres, hardware, the S3 and VPC services themselves | Who can read the bucket |
| That Block Public Access works when switched on | Whether it's switched on |
| That security groups filter traffic | Which ports are open, and to whom |
| That IAM enforces policies | What each role is allowed to do |

Every mistake in today's labs, and both changes in step 4, sit in the right-hand column.

```bash
terraform destroy                 # type "yes"; removes everything from step 1
rm -f customers.csv
```

## Takeaways
- Scanning code before deployment is necessary but not enough: the live cloud can change without the code changing.
- Keep infrastructure in code, and watch the live account continuously.
- The cloud provider secures the platform. How it's configured is always the customer's job.
