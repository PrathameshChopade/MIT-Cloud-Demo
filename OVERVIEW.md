# Securing the Path to the Cloud — Session Overview

Oct 20, 2026 · @Prathmesh

## What this session is about

This is a 90-minute hands-on session on how cloud security problems really happen, how to catch them before they reach the cloud, and how to keep the cloud the way it was built.

When people hear "cloud security", they often picture hackers breaking into Amazon or Microsoft data centres. In reality, the cloud providers protect their own buildings, hardware and networks very well. Most real breaches happen because of mistakes made by the people *using* the cloud:

- A password or access key accidentally saved into a code repository.
- Code that trusts whatever input it receives.
- A storage bucket or firewall rule set up so that "anyone on the internet" can reach it.
- A quick manual change in the live account that nobody reviewed.

The session follows a change from a developer's laptop into a real cloud account, with four stops along the way. At each one, participants see the mistake, catch it with a free tool, and fix it.

**Who it's for:** developers, testers, operations and DevOps engineers, and anyone curious about cloud security. Participants need basic comfort with a terminal. No cloud account and no prior security experience are required.

**What people leave with:** a clear picture of where cloud breaches come from, hands-on experience with widely used open-source security tools, a working example of an automated security gate, and an understanding of the shared responsibility model on a real AWS account.

## How the session works

Labs 1–3 run on each participant's own laptop, inside Docker. Lab 4 is a live demo by the facilitator on a real AWS account.

- **The toolbox.** All the security tools come pre-installed in one ready-made container called the toolbox. Participants open it with a single command and keep it open for the whole session. Nothing has to be installed on the laptop itself apart from Docker and Git.
- **Safe to experiment.** Participants work on the lab files exactly where they are in the repo, and can open them in their own editor. One Git command puts everything back to the original.
- **No internet needed on the day** for Labs 1–3: the toolbox is downloaded once, before the session.
- **Same pattern in every lab.** See the problem, catch it with a tool, fix it, and check that the tool is now happy.
- **Fake secrets only.** The passwords and access keys in the lab files look real so the tools detect them, but they don't work anywhere.

**Timing (90 minutes):** a 10-minute introduction to cloud basics and shared responsibility, a 5-minute toolbox walkthrough, four labs of about 15 minutes each, and 7 minutes of wrap-up and questions.

## The four labs

```text
                 Code on a developer laptop
                             |
                             v
  +-------------------------------------------------------+
  | Lab 1 · Secrets in Git                                |
  | Catches passwords and keys saved in code              |
  | Tool: gitleaks                                        |
  +-------------------------------------------------------+
                             |
                             v
  +-------------------------------------------------------+
  | Lab 2 · Insecure code                                 |
  | Catches bugs that let attackers run commands or       |
  | steal data                                            |
  | Tool: SonarQube (walkthrough)                         |
  +-------------------------------------------------------+
                             |
                             v
  +-------------------------------------------------------+
  | Lab 3 · The CI security gate                          |
  | Checks the cloud infrastructure code and blocks       |
  | unsafe deploys                                        |
  | Tools: Checkov, Jenkins (demo)                        |
  +-------------------------------------------------------+
                             |
                             v
  +-------------------------------------------------------+
  | Lab 4 · Into the cloud (demo on AWS)                  |
  | Deploys for real, then catches manual changes the     |
  | pipeline can't see                                    |
  | Tools: Terraform, AWS CLI                             |
  +-------------------------------------------------------+
                             |
                             v
                 Running safely in the cloud
```

### Lab 1 — Secrets in Git (15 min, hands-on)

**The problem:** a developer saves cloud access keys and a database password directly in the code and commits it to Git.

**What participants do:**

1. Commit the code with the secrets in it.
2. Run **gitleaks**, a secret scanner, which finds the keys immediately.
3. "Fix" it by deleting the secrets and committing again, then discover that gitleaks still finds them in the history.
4. Add a pre-commit hook: an automatic check that refuses any commit containing a secret.

**Why it matters:** Uber's AWS keys were found in a private code repository in 2016, exposing data on 57 million users. A leaked secret must be replaced, not just deleted.

### Lab 2 — Insecure code (20 min, hands-on plus demo)

**The problem:** a small Python service that looks normal but contains about twenty common security bugs, such as SQL injection, running whatever text it receives as code, and turning off certificate checks.

**What participants do:**

1. Read the code; each problem is explained in a comment.
2. Count how many they would have caught in a code review.
3. Watch the same code in **SonarQube**, the dashboard many companies use: the insecure version fails its quality gate, the fixed version passes after its hotspots are reviewed.
4. Compare the insecure and fixed versions side by side in VS Code.

**Why it matters:** these bugs let an attacker run commands on the server, steal data or take over sessions. A scanner finds them in seconds, before the code is ever deployed.

### Lab 3 — The CI security gate (15 min, hands-on plus demo)

**The problem:** a Terraform file describing the service's AWS infrastructure, with the classic cloud mistakes: a bucket that allows public access, SSH open to the internet, a server with a public IP and the old metadata service, an unencrypted disk, and a permission that allows everything.

**What participants do:**

1. Read the file; each problem is marked with a comment.
2. Run **Checkov**, which finds the mistakes without touching AWS.
3. Apply the fixes and scan again: it passes.
4. Watch the same check in a **Jenkins** pipeline: a red build with the deploy skipped, then a green build that deploys.

**Why it matters:** most cloud breaches come from misconfiguration. Checking the infrastructure code automatically, before anything is created, stops it reaching the cloud.

### Lab 4 — Into the cloud: deploy, drift and detect (15 min, facilitator demo)

**The problem:** a green pipeline only proves the *code* is safe. Once deployed, someone can still change the live cloud by hand.

**What participants watch:**

1. A small, secure setup is deployed to a real AWS account with Terraform: a private S3 bucket, a security group allowing HTTPS only, and a least-privilege IAM role.
2. The bucket is checked from the internet (access denied), and a file is shared safely with a link that expires.
3. A "colleague" makes two quick manual changes: SSH opened to the world, and the bucket's protection removed. Every scanner still passes.
4. A live posture check and `terraform plan` both detect the changes, and Terraform puts everything back.
5. The shared responsibility model on what was just built, then everything is removed.

**Why it matters:** the cloud provider secures the platform; how it's configured is always the customer's job, before *and* after deployment.

## What participants need

Participants need a laptop with Docker and Git, and about 15 minutes of setup a few days before the session.

1. Install Git and a Docker tool: Docker Desktop, Rancher Desktop, or Docker Engine inside WSL2 on Windows.
2. Download the lab kit.
3. Build the kit once with `docker compose build`. This downloads about 1.5 GB, so it should be done on a good connection.
4. Run the readiness check and confirm it says READY. If it doesn't, send the output to the facilitator before the session.

No cloud account is needed. Anyone whose laptop can't run Docker, for example because of company restrictions, can pair with a neighbour on the day.
