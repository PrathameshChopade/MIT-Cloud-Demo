# Lab 3 — The CI security gate (15 min)

**Goal:** check the cloud infrastructure automatically before it's deployed. You find the classic cloud mistakes in a Terraform file with Checkov, then watch a Jenkins pipeline block the deployment until they're fixed.

**The scenario:** the team describes its AWS setup in Terraform: a storage bucket, a firewall rule, a server and a permission policy. Someone took shortcuts to "just make it work", and the pipeline is about to deploy it. Would you let it?

**Where:** steps 2 and 3 run in the **toolbox**; the Jenkins part (step 4) is a facilitator demo.
**In your editor:** open `labs/lab3-ci-gate/start/main.tf`, and `labs/lab3-ci-gate/solution/main.tf` beside it.

> **Back to the toolbox for this lab.** Use the toolbox terminal from Lab 1. If you closed it, start it again from the repo folder with `docker compose run --rm toolbox`; it opens in the repo folder, so the commands below work as written. The Jenkins demo in step 4 is different: it runs in a **host terminal** (on Windows with WSL: an Ubuntu terminal), because it starts Docker containers.

## 1. Read the infrastructure

`start/main.tf` describes a storage bucket, a firewall rule, a server and a permission policy. Each `RISK` comment marks a problem; `solution/main.tf` has the fix on the same line.

| Problem | Why it matters | Fix |
|---|---|---|
| Bucket allows public access | Leaked buckets are among the most common cloud breaches | All four public-access settings `true` |
| SSH open to `0.0.0.0/0` | Anyone on the internet can try to log in | Only the internal network (better: no SSH) |
| Server has a public IP | Reachable directly from the internet | No public IP, behind a load balancer |
| Old metadata service (IMDSv1) | The path used in the 2019 Capital One breach | `http_tokens = "required"` (IMDSv2) |
| Disk not encrypted | Data exposed if a disk or snapshot leaks | `encrypted = true` |
| Policy allows `*` on `*` | A leaked credential means full account takeover | Only the actions and bucket the app needs |

To compare the files in VS Code: right-click `start/main.tf` → **Select for Compare**, then right-click `solution/main.tf` → **Compare with Selected**.

## 2. Scan the insecure version with Checkov

Checkov reads Terraform files and reports problems without touching AWS. In the **toolbox**, starting from the repo folder (`/workspace`), because the paths are relative to it:

```bash
cd /workspace
checkov -d labs/lab3-ci-gate/start --config-file scripts/checkov-baseline.yaml
# expect: FAILED checks for each problem in the table
```

This runs the team's **must-fix list** (`scripts/checkov-baseline.yaml`): the checks that always block a deployment. To see why a short list matters, try a full scan: `checkov -d labs/lab3-ci-gate/start --compact --quiet`.

## 3. Scan the fixed version

Still in the **toolbox**:

```bash
checkov -d labs/lab3-ci-gate/solution --config-file scripts/checkov-baseline.yaml
# expect: no failed checks
```

**Optional:** fix the `RISK` lines in `start/main.tf` yourself, rerun the step 2 command until it passes, then reset the file with `git restore labs/lab3-ci-gate/start`.

## 4. The same check in a pipeline (facilitator demo)

The facilitator shows a Jenkins pipeline with two stages:

```groovy
stage('Terraform security check') { sh 'checkov -d /lab3/demo-repo --config-file /lab3/demo-repo/checkov-baseline.yaml' }
stage('Deploy')                   { echo 'Deploying' }
```

- **Insecure version:** the check fails, the build goes **red** and **Deploy is skipped**.
- **Fixed version:** the check passes, the build goes **green** and Deploy runs.

The facilitator runs these in a **host terminal**, in the repo folder (not the toolbox). Creating the Jenkins job is a one-time step described in FACILITATOR.md.

```bash
rm -rf labs/lab3-ci-gate/demo-repo
docker compose run --rm toolbox bash labs/lab3-ci-gate/prepare-repo.sh labs/lab3-ci-gate/demo-repo
docker compose --profile jenkins up -d --build jenkins
# http://localhost:8080, job "secure-gate", Build Now: red build, Deploy skipped
docker compose run --rm toolbox bash labs/lab3-ci-gate/apply-fixes.sh labs/lab3-ci-gate/demo-repo
# Build Now again: green build, Deploy runs
```

## 5. Clean up

If you edited `start/main.tf`, put it back (in the **toolbox**):

```bash
git restore labs/lab3-ci-gate/start
```

Facilitator, in a **host terminal**:

```bash
docker compose --profile jenkins stop jenkins           # stop it, keep the job
rm -rf labs/lab3-ci-gate/demo-repo                      # remove the demo repo
```

## Takeaways
- Most cloud breaches come from misconfiguration, and infrastructure code can be scanned before anything is created.
- A pipeline gate makes the check automatic: nobody can forget it or skip it.
- Teams agree on a short must-fix list that blocks deployments, and track the rest.

**Next:** in Lab 4, the facilitator deploys to a real AWS account, and shows what a pipeline gate can't catch.
