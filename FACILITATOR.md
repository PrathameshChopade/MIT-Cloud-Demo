# Facilitator guide

Session: **Securing the path to the cloud**. Planned for 90 minutes, with 60- and 120-minute variants below.

## Agenda (90 minutes)

| Time | Segment | Format | Notes |
|---|---|---|---|
| 0–10 | Cloud basics and scope | Talk | See "Opening talk" |
| 10–15 | Toolbox walkthrough | Demo | Everyone opens `docker compose run --rm toolbox` |
| 15–30 | Lab 1: Secrets in Git | Hands-on | Your strongest material; take your time |
| 30–50 | Lab 2: Insecure code | SonarQube walkthrough | Participants read the code in VS Code (5 min), then you walk through SonarQube (15 min) |
| 50–65 | Lab 3: CI security gate | Hands-on, then Jenkins demo | Walk through the `RISK` lines in `main.tf`; finish on the red build, then the green one |
| 65–80 | Lab 4: Into the cloud | Your AWS demo | Deploy, drift, detect, fix, destroy |
| 80–90 | Recap and Q&A | Talk | Show the "where to go next" list from the README |

- **60 minutes:** shorten the intro to 7 minutes and skip the toolbox walkthrough. Lab 1: 12 minutes. Lab 2: 12 minutes with a 3-minute SonarQube demo. Lab 3: run Checkov on start and solution, then show Jenkins (10 minutes). Lab 4: 13 minutes. Wrap-up: 6 minutes.
- **120 minutes:** give each hands-on lab 5 more minutes. Let participants write the `eval` and `yaml` fixes in Lab 2 themselves, run Checkov's full scan in Lab 3 and discuss which findings matter, and add a 10-minute discussion on how their own teams handle secrets and manual cloud changes.

## Opening talk (10 minutes)

1. **What cloud computing is.** The five NIST characteristics: on-demand self-service, broad network access, resource pooling, rapid elasticity, and measured service.
2. **Service models** (IaaS, PaaS, SaaS) and **deployment models** (public, private, hybrid). Use your Platform9 work as the private cloud example: the same self-service model as AWS, running on the company's own hardware.
3. **The building blocks** you'll see in Lab 4: compute, storage (S3), networking (VPC, subnets, security groups) and identity (IAM).
4. **Shared responsibility.** The provider secures the cloud itself: data centres, hardware and the hypervisor. You secure what you put in it: identities, configuration, code and data. Everything in today's labs is on your side of that line.
5. **Where breaches come from.** Industry breach reports consistently rank stolen credentials and misconfiguration among the top causes. Exotic zero-days are rare by comparison. Cases you can mention (one line each):
   - **Uber (2016):** AWS keys in a private GitHub repo.
   - **Capital One (2019):** SSRF to the EC2 metadata service, IAM role credentials stolen, S3 data read.
   - **Codecov (2021):** a credential extracted from a Docker image was used to modify their uploader script.
   - **Microsoft AI research (2023):** an over-permissive Azure storage SAS token shared on GitHub exposed 38 TB of internal data.
6. **Scope statement. Say this explicitly:** "Today is about catching security problems on the way to the cloud and keeping the cloud the way we built it: in code, pipelines and the live account. Kubernetes hardening, incident response and compliance frameworks are big topics of their own. Questions on those go on the parking-lot board, and I'll follow up afterwards."

## Lab 2 SonarQube demo setup

Only on your machine. SonarQube needs about 2–3 GB of RAM, so stop Jenkins first (`docker compose --profile jenkins stop jenkins`) or raise the WSL memory cap to 8 GB.

**Once, while preparing (about 10 minutes):**
1. Start SonarQube and wait about 2 minutes:
   ```bash
   docker compose --profile sonarqube up -d sonarqube
   docker compose --profile sonarqube logs -f sonarqube    # wait for "SonarQube is operational", then Ctrl+C
   ```
2. Open http://localhost:9000, log in as `admin` / `admin`, and set a new password when asked.
3. Create a token: avatar (top right) → **My Account** → **Security** → **Generate Tokens** → name `demo`, type **Global Analysis Token** → **Generate**. Copy it; it's shown only once.
4. Create a quality gate that checks **all** the code. The default gate ("Sonar way") only checks *new* code, so a project's first analysis always passes, however bad the code is.
   - **Quality Gates** (top menu) → **Create** → name it `Workshop`.
   - Add these conditions, choosing **On Overall Code** each time:
     - **Security Rating** is worse than **A**
     - **Reliability Rating** is worse than **A**
     - **Security Hotspots Reviewed** is less than **100%**
   - Click **Set as Default**, so every project uses it.
   - Condition names can differ slightly between SonarQube versions. If one isn't listed, pick the closest security or hotspot measure.
5. Analyse the insecure code and the fixed code as two projects:
   ```bash
   export SONAR_TOKEN=<your token>
   # the insecure code: start/ -> project "lab2-start"
   docker compose --profile sonarqube run --rm -e SONAR_TOKEN sonar-scanner \
     -Dsonar.projectKey=lab2-start "-Dsonar.projectName=Lab 2 - Insecure code (start)" -Dsonar.sources=start
   # the fixed code: solution/ -> project "lab2-solution"
   docker compose --profile sonarqube run --rm -e SONAR_TOKEN sonar-scanner \
     -Dsonar.projectKey=lab2-solution "-Dsonar.projectName=Lab 2 - Fixed code (solution)" -Dsonar.sources=solution
   ```
6. Check the results. Expected: **lab2-start fails** the gate, with security issues and many hotspots. **lab2-solution** has no security issues but may still list a few hotspots (for example, the safe `subprocess` call), so it fails only on "Security Hotspots Reviewed". Leave that for the live demo (below).
7. Note what each project shows (issue counts, hotspots, gate result), so you can talk about it confidently.

The projects and results are kept in Docker volumes, so on the day you only start SonarQube (step 1) and open the browser. Take screenshots as a backup.

**What to show in the session (about 15 minutes, after participants have read the code):**
- **Projects list:** start (Failed) vs solution side by side.
- **Start project → Issues:** filter by **Security**. Click one, such as the disabled certificate check or the unverified token, to show the highlighted line and the explanation.
- **Start project → Security Hotspots:** the `eval`, `shell=True`, MD5, SQL and `random` problems from the code's `RISK` comments, each with the risk and how to fix it.
- **Solution project → Security Hotspots → review live:** open each remaining hotspot, read the code, set its status to **Safe** with a one-line reason (for example, "fixed argument list, no shell"). Refresh the project: the gate turns **Passed**. If it doesn't update, rerun the solution scan. This shows the point of hotspots: a person decides, and the decision is recorded.
- **The message:** "Code review missed these because the code looks normal. SonarQube checks every line on every pull request, with a dashboard, history and a pass/fail gate."

**Things to know if asked:**
- **Security hotspot vs vulnerability:** a hotspot is code that *may* be dangerous and needs a human to review it. A vulnerability is a confirmed problem.
- **Free vs paid:** the free Community Build doesn't do taint analysis, meaning tracing untrusted input through the code into a dangerous call. The paid editions do. That's why several findings appear as hotspots here.
- **SonarQube for IDE:** a free VS Code extension (formerly SonarLint) that underlines the same problems while you type, with no server.

## Lab 3 Jenkins demo setup

**Once, while preparing:**
```bash
# 1. Build the toolbox first (Jenkins reuses its gitleaks), then Jenkins
docker compose build
docker compose run --rm toolbox bash /workspace/labs/lab3-ci-gate/prepare-repo.sh /workspace/labs/lab3-ci-gate/demo-repo
docker compose --profile jenkins up -d --build jenkins
```
2. Open http://localhost:8080 and create the job: **New Item** → name it `secure-gate` → **Pipeline** → **OK**. Under **Pipeline**, set **Definition** to **Pipeline script**, paste the contents of `labs/lab3-ci-gate/Jenkinsfile` into the script box, and **Save**. Jenkins reads `labs/lab3-ci-gate/demo-repo` directly (docker-compose mounts `labs/lab3-ci-gate` at `/lab3`), so no Git checkout is involved, and resetting `demo-repo` needs no Jenkins restart.
3. Click **Build Now**. The build should go red: the **Terraform security check** stage fails and **Deploy** is skipped.

**Live in the session:**
1. Show the red build and click into each stage log.
2. Apply the fixes:
   ```bash
   docker compose run --rm toolbox bash /workspace/labs/lab3-ci-gate/apply-fixes.sh /workspace/labs/lab3-ci-gate/demo-repo
   ```
3. Click **Build Now** again. The build goes green and the Deploy stage runs.
4. **Bridge to Lab 4:** "Deploy is simulated here. Now let's actually deploy, and see what a green pipeline can't protect us from."

**To reset for the next dry run:** delete `labs/lab3-ci-gate/demo-repo` and run `prepare-repo.sh` again (the Jenkins job can stay).

**About the Jenkins setup:** it has no login and listens only on localhost. It's fine for a demo, but it's also a good talking point: an exposed, unauthenticated CI server is itself a serious cloud security risk.

## Lab 4 AWS demo setup

**What you need:** a sandbox or personal AWS account (never production), with a default VPC in the region you use. The demo creates a bucket, a security group and an IAM role, all free, briefly makes a file of fake data public, and removes everything at the end.

**Once, in Ubuntu:**
1. Install Terraform:
   ```bash
   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
     | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt-get update && sudo apt-get install -y terraform
   ```
2. Install the AWS CLI v2, plus `qrencode` (draws the QR code for the phone-leak step):
   ```bash
   sudo apt-get install -y unzip qrencode
   curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
   unzip -q /tmp/awscliv2.zip -d /tmp && sudo /tmp/aws/install
   aws --version
   ```
3. Sign in with **short-lived credentials**: `aws configure sso` if your account uses IAM Identity Center, or `aws login` to reuse your console sign-in. Avoid creating long-lived access keys; if you have to, use a dedicated IAM user for the demo and delete its keys afterwards. Sign in as an IAM admin user, not root: `get-caller-identity` on the projector shows which. In WSL, if the browser doesn't open, copy the printed link into your Windows browser, or use `aws login --remote`.

   Terraform can't read an `aws login` session directly, so add a `terraform` profile once that reuses it:
   ```bash
   grep -qs '^\[profile terraform\]' ~/.aws/config || cat >> ~/.aws/config <<'EOF'

   [profile terraform]
   credential_process = aws configure export-credentials --profile default --format process
   region = ap-south-1
   EOF
   ```
   Then, **in every terminal you use for the demo, run `export AWS_PROFILE=terraform` once.** Terraform, the AWS CLI, `check.sh` and `drift.sh` then all use your current sign-in, with fresh credentials on every command. If anything says the credentials expired, run `aws login` again.
4. Set a safety net: **Billing → Budgets → Create budget**, a $5 monthly cost budget with an email alert.
5. The region defaults to `ap-south-1` (Mumbai). To use another one, add `-var region=<region>` to every `terraform plan`, `apply` and `destroy`.
6. Check the account-level **Block Public Access**. If it's fully on, the phone-leak step is blocked (which is exactly what that guardrail is for):
   ```bash
   account=$(aws sts get-caller-identity --query Account --output text)
   aws s3control get-public-access-block --account-id "$account"
   # "NoSuchPublicAccessBlockConfiguration" or BlockPublicPolicy/RestrictPublicBuckets false: the leak demo will work
   ```
   If it's on, choose one:
   - **Keep it on** and use it as the lesson: run `drift.sh`, show AWS refusing the public policy, and explain that an account-wide guardrail stopped the leak.
   - **Switch the two policy settings off for the demo only**, in a sandbox account, and switch them back straight after:
     ```bash
     aws s3control put-public-access-block --account-id "$account" --public-access-block-configuration \
       BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false
     # after the demo:
     aws s3control put-public-access-block --account-id "$account" --public-access-block-configuration \
       BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
     ```
7. Do a full run of the [Lab 4 README](labs/lab4-into-the-cloud/README.md), including `terraform destroy`, and screen-record it as a backup.

**About the phone leak:** between `drift.sh` and `terraform apply`, the fake customer file is readable by anyone with the link. Keep that window to the demo itself, and never put real data in the bucket. Test the QR code with your own phone during the rehearsal: projector glare can make it hard to scan, so zoom the terminal in.

**On the projector:**
- Never show `~/.aws/`, `aws configure list`, or any key. `aws sts get-caller-identity` shows your account ID; that isn't a secret, but blur it in recordings if you prefer.
- Sign in again shortly before the session, so the short-lived credentials don't expire mid-demo.

**After the demo:** check that `terraform destroy` finished, then delete the local state: `rm -rf labs/lab4-into-the-cloud/terraform/.terraform* labs/lab4-into-the-cloud/terraform/terraform.tfstate*`.

## Preparation checklist (session on Thursday)

- [ ] `docker compose build` and `verify.sh` show READY
- [ ] Run Labs 1–3 end to end in the toolbox; note anything that differs from the "expect" comments
- [ ] SonarQube: one-time setup done, both projects scanned, Workshop gate set
- [ ] Jenkins: job created, red build then green build confirmed, demo repo reset
- [ ] AWS: Terraform and AWS CLI installed, signed in, budget alert set, Lab 4 run end to end and destroyed
- [ ] Backups: screenshots of SonarQube, a recording of Jenkins and of Lab 4
- [ ] Slides (8–10): title, agenda, cloud basics and building blocks, shared responsibility, breach stories, one per lab, wrap-up
- [ ] Setup email sent to participants
- [ ] Two full dry runs with a timer

### Things to check on the first run

- **Tool options:** `gitleaks git --pre-commit --staged`, `gitleaks dir`, and `checkov --config-file`. Confirm the start files fail and the solution files pass in Labs 1–3.
- **The Checkov must-fix list:** run it against `labs/lab3-ci-gate/start` (should fail), `labs/lab3-ci-gate/solution` (should pass) and `labs/lab4-into-the-cloud/terraform` (should pass). If a check ID in `scripts/checkov-baseline.yaml` doesn't behave as expected, change or remove it, then rebuild the toolbox.
- **Pinned versions:** Checkov image `3.3.26` (the toolbox is built on it), gitleaks `8.21.2`, SonarQube `26.9.0`, scanner `12.2.0`. If a download fails, check the project's releases page. (Trivy, used in an earlier version of this kit, had to be re-pinned because old releases were removed from GitHub after the March 2026 supply-chain incident. That's a good story about why pinning and checksums matter.)
- **The Jenkins image** uses the current LTS. If the Checkov install fails there because of the Python version, pin an older LTS tag in `labs/lab3-ci-gate/jenkins/Dockerfile`.

## Setup email for participants

> Subject: Prep for Thursday's cloud security session (about 15 minutes)
>
> Hi all,
>
> The session is hands-on, so please set up your laptop before Thursday:
>
> 1. Install Git and Docker Desktop (Rancher Desktop, or Docker Engine in WSL2, also work).
> 2. Clone the lab repo: `git clone https://github.com/PrathameshChopade/MIT-Cloud-Demo.git`
> 3. In the repo folder, run `docker compose build`. This downloads about 400 MB, so please do it on a good connection.
> 4. Run `verify.ps1` (Windows) or `verify.sh` (macOS/Linux/WSL) and check that it says READY.
>
> You don't need a cloud account. If anything fails, reply with the output and I'll help before the session. If your laptop can't run Docker, don't worry: you can pair with someone on the day.

## Fallbacks

| Problem | Fallback |
|---|---|
| Some participants can't run Docker | They pair with a neighbour |
| The Wi-Fi is down | Labs 1–3 need no internet once the toolbox is built. Bring it on a USB drive (`docker save -o toolbox.tar secure-path-toolbox:1.0`; participants run `docker load -i toolbox.tar`). Lab 4 needs internet on your laptop: use a phone hotspot |
| Jenkins misbehaves | Play the recording, or run the Checkov command live in the toolbox. It's the same check |
| AWS sign-in expired or AWS unreachable | Play the Lab 4 recording and talk over it |
| Running out of time | Lab 3: skip the full Checkov scan and show only Jenkins. Lab 4: skip step 2 (the presigned URL) |

## Cleanup

| What | Command (from the repo folder) |
|---|---|
| Reset all lab files to the repo version | `rm -rf labs/lab1-secrets/start/.git && git restore labs && git clean -fdq labs` |
| Reset the Jenkins demo repo | `rm -rf labs/lab3-ci-gate/demo-repo` |
| Stop SonarQube and Jenkins, keep their data | `docker compose --profile jenkins --profile sonarqube down` |
| Also delete their data | add `-v` to the command above |
| Remove the Lab 4 AWS resources | `cd labs/lab4-into-the-cloud/terraform && terraform destroy` |
| Remove Lab 4 local state | `rm -rf labs/lab4-into-the-cloud/terraform/.terraform* labs/lab4-into-the-cloud/terraform/terraform.tfstate*` |
| Remove all kit images | `docker compose --profile jenkins --profile sonarqube down -v --rmi all` |

## AWS in 10 lines (enough for this session)

- **IAM user:** a long-lived identity with a password and/or access keys. Avoid users for workloads.
- **IAM role:** an identity that applications or services assume, receiving short-lived credentials automatically. Prefer roles.
- **IAM policy:** JSON listing which actions are allowed on which resources. Least privilege means granting only the specific actions on the specific resources a workload needs.
- **MFA:** require it for every human, especially the root account, which should almost never be used.
- **S3 Block Public Access:** four settings that override any public access. On by default for new buckets; turn them on at the account level too.
- **VPC and security groups:** a VPC is your private network in AWS, split into subnets. A security group is a stateful firewall on each resource. Never allow `0.0.0.0/0` on SSH or RDP.
- **Instance metadata service (IMDS):** at `169.254.169.254`, it gives an instance its role credentials. IMDSv2 requires a session token, which defeats simple SSRF attacks.
- **CloudTrail:** logs every API call (who did what, and when). It's your audit trail, and how you'd find out who made the Lab 4 "drift" changes.
- **AWS Config / Security Hub:** check a live account against rules continuously. `check.sh` in Lab 4 is a miniature version.
- **Secrets Manager / SSM Parameter Store:** where secrets belong, instead of in code or user data.

## Q&A cheat sheet

**"Is a pre-commit hook enough?"**
No. Developers can skip it, and each one has to install it. That's why teams run the same checks in CI as well, where they can't be skipped, like the gate in Lab 3.

**"Why not just keep repos private?"**
Uber's leaked keys were in a private repo. Access to repos is wider than people think: contractors, CI systems, forks, laptops.

**"How do you remove a secret from Git history?"**
First rotate or revoke the secret. Then use `git filter-repo` or BFG and force-push. Clones and caches still have copies, which is why rotation comes first.

**"What about false positives?"**
Every scanner has them. Suppress each one explicitly with a written reason (`# nosec B603 - fixed argument list`, `#checkov:skip=CKV_AWS_xx: reason`) and review suppressions like any other code change.

**"SAST vs DAST vs SCA?"**
- SAST reads the code (SonarQube; for Python also Bandit).
- DAST attacks the running application.
- SCA checks your dependencies for known vulnerabilities (for example Trivy, Dependabot, pip-audit).

Today's labs cover secret scanning, SAST, infrastructure-as-code scanning and a live posture check.

**"What is drift, and how do you stop it?"**
Drift is when the live cloud no longer matches the code, usually because someone changed it by hand. Reduce it by giving people read-only console access in production, making changes through code and pipelines, and running `terraform plan` or a posture tool regularly to spot it.

**"Is the Terraform state file sensitive?"**
Yes. It can contain resource details and sometimes secrets. Store it in an encrypted remote backend with restricted access (for example an S3 bucket with locking), never in Git. The kit's `.gitignore` excludes it.

**"What about Kubernetes?"**
The same idea applies. Scan manifests and Helm charts with Checkov in the pipeline, and scan images before they're deployed. At runtime, the main topics are RBAC, network policies, not running containers as root, and Pod Security Standards. "That's a session of its own. I'll share some links."

**"What about Azure and GCP?"**
The concepts are the same and the names differ:
- Azure: Key Vault, NSGs, Entra ID roles, Blob Storage.
- GCP: Secret Manager, firewall rules, service accounts, Cloud Storage.

gitleaks, SonarQube and Checkov work the same for all three.

**"What's shift-left?"**
Moving security checks earlier in the process (to the laptop, the commit or the pipeline), where problems are cheaper to fix than in production.

**"What's CSPM?"**
Cloud Security Posture Management: continuously scanning a live cloud account for misconfigurations. Examples are Prowler (open source), AWS Security Hub and Microsoft Defender for Cloud. It complements pre-deployment scanning, because people also change things by hand (Lab 4).

**"How do these ideas apply to OpenStack or private clouds?"**
They apply one-to-one:
- Keystone projects and roles are the equivalent of IAM.
- Neutron networks and security groups are the equivalent of VPCs and AWS security groups.
- Swift is the object storage, like S3.
- Barbican is the secrets store.
- The metadata service is at the same address, `169.254.169.254`.

**Any question you can't answer:**
"Good question. That's beyond what I've worked with hands-on, so I'll find out properly and follow up." Write it on the parking-lot board, and send the answers afterwards.
