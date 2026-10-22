# Commands

Every command for the session in one place. Each lab's README explains what the commands do and what to look for.

Where each block runs:
- **Host terminal:** a terminal on your machine, in the repo folder (on Windows with WSL: the Ubuntu terminal).
- **Toolbox:** the container started with `docker compose run --rm toolbox`. It opens in the repo folder, so every path is the same as in the repo.

## Setup (before the session)

### Option A: Windows with WSL2 + Ubuntu + Docker Engine (the facilitator's setup)

PowerShell, once:
```powershell
wsl --install -d Ubuntu-24.04
```

Ubuntu, once (installs Docker Engine from Docker's official repository):
```bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl git
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER      # then close and reopen the Ubuntu terminal
docker run --rm hello-world        # check Docker works
```

### Option B: Docker Desktop, Rancher Desktop, Podman Desktop or Colima

Install one of them and Git, then continue below.

### Everyone: get the repo, build and check

Host terminal:
```bash
git clone https://github.com/PrathameshChopade/MIT-Cloud-Demo.git
cd MIT-Cloud-Demo
docker compose build
bash verify.sh                     # Windows without WSL: powershell -ExecutionPolicy Bypass -File .\verify.ps1
# expect: READY
```

## Start the toolbox (Labs 1 and 3)

Host terminal, in the repo folder:
```bash
docker compose run --rm toolbox
```
Keep it open. It starts in the repo folder (`/workspace`). Type `exit` to leave.

## Lab 1 — Secrets in Git

Toolbox:
```bash
cd labs/lab1-secrets/start
git init -q && git add . && git commit -qm "Add order export service"
gitleaks git -v                    # leak found

cp -r ../solution/. .
git add -A && git commit -qm "Move secrets to environment variables"
gitleaks dir .                     # current files: clean
gitleaks git -v                    # history: still found
git show HEAD~1:app/config.py      # the key is still in history

# Add a pre-commit hook that blocks secrets
cat > .git/hooks/pre-commit <<'EOF'
#!/bin/sh
exec gitleaks git --pre-commit --staged --redact -v
EOF
chmod +x .git/hooks/pre-commit
echo 'BACKUP_KEY = "AKIARZ5TQW7XKMB3NPLD"' > app/backup.py
git add app/backup.py && git commit -m "Add backup job"   # blocked
git log --oneline                  # still 2 commits
```

Reset Lab 1 (toolbox):
```bash
cd /workspace
rm -rf labs/lab1-secrets/start/.git
git restore labs/lab1-secrets && git clean -fdq labs/lab1-secrets
```

## Lab 2 — Insecure code (SonarQube)

**Everyone:** open `labs/lab2-insecure-code/start/report_service.py` in VS Code. Each problem has a `RISK` comment. The fixed version is `labs/lab2-insecure-code/solution/report_service.py`.

**Facilitator**, host terminal, in the repo folder (once, before the session):
```bash
docker compose --profile sonarqube up -d sonarqube
docker compose --profile sonarqube logs -f sonarqube   # wait for "SonarQube is operational", then Ctrl+C
# Browser: http://localhost:9000, log in as admin/admin and set a password,
# and create a Global Analysis Token (avatar > My Account > Security)
export SONAR_TOKEN=<your token>
docker compose --profile sonarqube run --rm -e SONAR_TOKEN sonar-scanner \
  -Dsonar.projectKey=lab2-start "-Dsonar.projectName=Lab 2 - Insecure code (start)" -Dsonar.sources=start
docker compose --profile sonarqube run --rm -e SONAR_TOKEN sonar-scanner \
  -Dsonar.projectKey=lab2-solution "-Dsonar.projectName=Lab 2 - Fixed code (solution)" -Dsonar.sources=solution
```
On the day: `docker compose --profile sonarqube start sonarqube`, wait about 2 minutes, open http://localhost:9000.

## Lab 3 — The CI security gate

**Everyone**, toolbox:
```bash
cd /workspace                      # the repo folder: the paths below start here
checkov -d labs/lab3-ci-gate/start --config-file scripts/checkov-baseline.yaml      # FAILED checks
checkov -d labs/lab3-ci-gate/solution --config-file scripts/checkov-baseline.yaml   # no failures
```
If you edited `start/main.tf` yourself, reset it with `git restore labs/lab3-ci-gate/start`.

**Facilitator**, Jenkins demo, host terminal, in the repo folder:
```bash
rm -rf labs/lab3-ci-gate/demo-repo
docker compose run --rm toolbox bash labs/lab3-ci-gate/prepare-repo.sh labs/lab3-ci-gate/demo-repo
docker compose --profile jenkins up -d --build jenkins
# Browser: http://localhost:8080, job "secure-gate" (setup in FACILITATOR.md), Build Now: red build
docker compose run --rm toolbox bash labs/lab3-ci-gate/apply-fixes.sh labs/lab3-ci-gate/demo-repo
# Build Now again: green build
```

## Lab 4 — Into the cloud (facilitator demo on AWS)

Once per machine: sign in, and add a `terraform` profile that reuses your `aws login` session (Terraform can't read that session directly):
```bash
aws login
grep -qs '^\[profile terraform\]' ~/.aws/config || cat >> ~/.aws/config <<'EOF'

[profile terraform]
credential_process = aws configure export-credentials --profile default --format process
region = ap-south-1
EOF
```
Also install `qrencode` (draws the QR code): `sudo apt-get install -y qrencode` on Ubuntu, `brew install qrencode` on macOS.

Host terminal, in the repo folder:
```bash
cd labs/lab4-into-the-cloud/terraform
export AWS_PROFILE=terraform                                  # once per terminal
terraform init && terraform plan && terraform apply           # type: yes

bucket=$(terraform output -raw bucket_name); region=$(terraform output -raw region)   # takes a few seconds
url="https://$bucket.s3.$region.amazonaws.com/customers.html"
aws s3 cp ../customers.html "s3://$bucket/" --content-type text/html --cache-control no-store
echo "Public link: $url"
curl -s -o /dev/null -w "%{http_code}\n" "$url"          # 403: open the link in a browser, AccessDenied
shared=$(aws s3 presign "s3://$bucket/customers.html" --expires-in 120 --region "$region")
echo "Presigned link (valid 2 minutes): $shared"
curl -s -o /dev/null -w "%{http_code}\n" "$shared"       # 200: open it in a browser, the page opens

bash ../check.sh                   # PASS, PASS, PASS
bash ../drift.sh                   # manual changes; prints the link and a QR code: participants scan it
curl -s -o /dev/null -w "%{http_code}\n" "$url"          # 200: the fake customer page, readable by anyone
bash ../check.sh                   # FAIL, FAIL, FAIL
terraform plan                     # shows the drift
terraform apply                    # puts it back
bash ../check.sh                   # PASS, PASS, PASS
curl -s -o /dev/null -w "%{http_code}\n" "$url"          # 403 again: participants refresh their phones

terraform destroy
```

## Switching demos and cleaning up

Host terminal, in the repo folder:
```bash
docker compose --profile jenkins stop jenkins          # free memory before SonarQube
docker compose --profile sonarqube stop sonarqube      # free memory before Jenkins
docker compose --profile jenkins --profile sonarqube down       # stop demos, keep their data
docker compose --profile jenkins --profile sonarqube down -v    # also delete their data
```

Reset every lab file to the repo version (toolbox, or host terminal in the repo folder):
```bash
rm -rf labs/lab1-secrets/start/.git
git restore labs && git clean -fdq labs
```
