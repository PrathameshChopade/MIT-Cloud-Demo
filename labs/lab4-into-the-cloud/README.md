# Lab 4 — Into the cloud: deploy, drift and detect (15 min, facilitator demo)

**Goal:** finish the path to the cloud. Code that passed every check is deployed to a real AWS account. Then someone changes the live cloud by hand, a file leaks to the internet, and every pre-deployment scanner still says "all good". This lab shows how that gap is closed.

**Covers:** storage (S3), networking (VPC and security groups), identity (IAM roles) and the shared responsibility model, on a real AWS account.

**Cost:** nothing meaningful. A bucket, a tiny file of fake data, a security group and an IAM role. No servers are launched, and step 6 removes everything.

**Where:** the facilitator's Ubuntu terminal, with Terraform and the AWS CLI installed and signed in (see FACILITATOR.md). The Checkov step runs in the toolbox. **Participants need only their phones** for step 4.

```bash
cd labs/lab4-into-the-cloud/terraform
```

## 1. Gate, then deploy

Toolbox, from the repo folder (the same must-fix list the CI gate uses in Lab 3):
```bash
checkov -d labs/lab4-into-the-cloud/terraform --config-file scripts/checkov-baseline.yaml
# expect: no failed checks
```

Ubuntu terminal:
```bash
aws sts get-caller-identity       # who am I? (account and role; never show keys)
export AWS_PROFILE=terraform      # once per terminal (profile setup: FACILITATOR.md, Lab 4)
terraform init
terraform plan                    # 8 resources to add: read them out
terraform apply                   # type "yes"
```

What now exists, and its cloud building block:

| Resource | Building block | Secure by default because |
|---|---|---|
| S3 bucket | Storage | All four Block Public Access settings on, encrypted, versioned, HTTPS-only policy |
| Security group in the default VPC | Networking | HTTPS only, no SSH |
| IAM role with an inline policy | Identity | Can only read and write files in that one bucket |

## 2. Put "customer data" in it and check from the outside

```bash
bucket=$(terraform output -raw bucket_name); region=$(terraform output -raw region)
url="https://$bucket.s3.$region.amazonaws.com/customers.html"
aws s3 cp ../customers.html "s3://$bucket/" --content-type text/html --cache-control no-store

echo "Public link: $url"
curl -s -o /dev/null -w "%{http_code}\n" "$url"
# expect: 403. Open the link in a browser: AccessDenied

shared=$(aws s3 presign "s3://$bucket/customers.html" --expires-in 120 --region "$region")
echo "Presigned link (valid 2 minutes): $shared"
curl -s -o /dev/null -w "%{http_code}\n" "$shared"
# expect: 200. Open the link in a browser within 2 minutes: the "Customer export" page opens
```

The file is `customers.html`, a small page of fake customer records that opens in any browser, including phones.

**On screen:** open both links in browser tabs side by side. The public one shows AccessDenied, and the presigned one opens the page. Refresh the presigned one after two minutes: "Request has expired".

**Say:** sharing a file doesn't need a public bucket. A presigned link gives one person access to one file, for a short time. The data is fake.

## 3. Everything is green

```bash
bash ../check.sh                  # expect: PASS, PASS, PASS
```

## 4. Drift: a colleague "just fixes something", and the data leaks

```bash
bash ../drift.sh
```

The script opens SSH to the world, removes the bucket's protection, and adds a policy that lets anyone read the files. It then prints the file's link and a **QR code**.

**Ask everyone to scan the QR code with their phone:** the "customer data" opens in their browser. It has leaked to the whole internet.

```bash
curl -s "$url"                    # expect: the file contents, with no credentials at all
bash ../check.sh                  # expect: FAIL, FAIL, FAIL
```

**Say:** the code hasn't changed, so gitleaks, SonarQube and Checkov would all still pass. Pre-deployment scanners only see code. They can't see what people do in the live account.

## 5. Detect and fix

```bash
terraform plan
# expect: the extra SSH rule removed, Block Public Access re-created, the bucket policy changed back
terraform apply                   # puts the cloud back the way the code says
bash ../check.sh                  # expect: PASS, PASS, PASS
curl -s -o /dev/null -w "%{http_code}\n" "$url"   # expect: 403
```

**Ask everyone to refresh the page on their phone:** Access Denied.

**Say:** two habits close the gap:
- **Infrastructure as code is the source of truth.** Changes go through code and review, and `terraform plan` shows any drift.
- **Continuous posture checks on the live account,** like `check.sh` but running all the time: AWS Security Hub, AWS Config or Prowler. In a real incident you would also check the S3 access logs or CloudTrail to see who downloaded the file while it was public.

## 6. Shared responsibility, then clean up

| AWS secured | We decided |
|---|---|
| Data centres, hardware, the S3 and VPC services themselves | Who can read the bucket |
| That Block Public Access works when switched on | Whether it's switched on |
| That security groups filter traffic | Which ports are open, and to whom |
| That IAM enforces policies | What each role is allowed to do |

Every mistake in today's labs, and all three changes in step 4, sit in the right-hand column.

```bash
terraform destroy                 # type "yes"; removes everything from step 1
```

## Takeaways
- Scanning code before deployment is necessary but not enough: the live cloud can change without the code changing.
- Keep infrastructure in code, and watch the live account continuously.
- The cloud provider secures the platform. How it's configured is always the customer's job.
