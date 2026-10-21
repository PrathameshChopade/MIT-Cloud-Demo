# Securing the path to the cloud

A hands-on session on cloud computing and cloud security.

Most cloud breaches start with mistakes made by the people using the cloud: a password committed to Git, insecure code, or a misconfigured bucket or firewall rule. In this session you'll find and fix these on your own laptop, see a CI pipeline block an insecure deployment, then watch a real AWS deployment and see why checking code before deployment isn't the whole story. You don't need a cloud account.

| Lab | Topic | Tools | Format |
|---|---|---|---|
| [Lab 1](labs/lab1-secrets/README.md) | Secrets in Git | git, gitleaks | Hands-on |
| [Lab 2](labs/lab2-insecure-code/README.md) | Insecure code | SonarQube | Read the code, plus a SonarQube walkthrough |
| [Lab 3](labs/lab3-ci-gate/README.md) | The CI security gate: checking cloud infrastructure | Terraform, Checkov, Jenkins | Hands-on, plus a Jenkins demo |
| [Lab 4](labs/lab4-into-the-cloud/README.md) | Into the cloud: deploy, drift and detect | Terraform, AWS CLI | Facilitator demo on AWS |

**Every command for setup and all four labs is in [COMMANDS.md](COMMANDS.md).** The slides are in [presentation/](presentation/).

## Before the session (about 15 minutes, mostly downloading)

1. **Install Git and Docker Desktop.**
   - **Docker Desktop:** https://www.docker.com/products/docker-desktop/. If your company doesn't license Docker Desktop, Rancher Desktop, Podman Desktop or Docker Engine in WSL2 also work.
   - **Git:** https://git-scm.com/downloads.
2. **Clone this repo** and open a terminal in its folder:
   ```bash
   git clone https://github.com/<github-user>/secure-path-to-cloud.git
   cd secure-path-to-cloud
   ```
3. **Build the toolbox once.** This needs about 1.5 GB of disk space and a decent connection:
   ```bash
   docker compose build
   ```
4. **Check you're ready:**
   ```powershell
   # Windows
   powershell -ExecutionPolicy Bypass -File .\verify.ps1
   ```
   ```bash
   # macOS / Linux / WSL
   bash verify.sh
   ```
   You should see `READY`. If you don't, send the output to the facilitator before the session.

## During the session

Open the toolbox, which contains every tool used in Labs 1–3:

```bash
docker compose run --rm toolbox
```

Keep this shell open for the whole session.

The toolbox starts in the repo folder, so every path is the same as in the repo (`labs/lab1-secrets/start`, `scripts/checkov-baseline.yaml`, and so on). Open the same files in your own editor, for example VS Code, while you run the tools in the toolbox.

To put every lab file back to the repo version after a run:
```bash
rm -rf labs/lab1-secrets/start/.git
git restore labs && git clean -fdq labs
```

If your laptop has problems on the day, pair up with a neighbour. Every lab works fine with two people at one screen.

## After the session: where to go next
- OWASP Top 10 and the OWASP Cheat Sheet Series
- AWS Well-Architected Framework, Security Pillar
- CIS Benchmarks (hardening guides for operating systems and cloud accounts)
- Prowler (open source): scans a live AWS, Azure or GCP account for misconfigurations
