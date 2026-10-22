# Lab 2 — Insecure code, found by SonarQube (20 min)

**Goal:** see how a code-scanning platform, SonarQube, finds security bugs in ordinary-looking code, explains them, and blocks the code with a pass/fail **quality gate**.

**The scenario:** an internal Python service builds, archives and shares customer reports. It works, it passed code review, and it contains about twenty security bugs.

**Real-world context:** in 2023, a single SQL injection bug in the MOVEit file-transfer product let attackers steal data from thousands of organisations.

**Where:** the facilitator runs SonarQube on screen. To follow along on your own laptop, you need about 3 GB of free memory; run the commands from the repo folder in a host terminal (not the toolbox).
**In your editor:** `labs/lab2-insecure-code/start/report_service.py` (insecure) and `solution/report_service.py` (fixed).

## The code

`start/report_service.py` has about twenty bugs, each marked with a `RISK` comment and a `FIX` comment. `solution/report_service.py` is the same service with every bug fixed.

| Problem | In the code | Fix |
|---|---|---|
| SQL injection | Customer ID pasted into the SQL text | Parameterised query |
| Command injection | `subprocess.run(..., shell=True)` | Argument list, no shell |
| Code execution | `eval()`, `pickle.loads()`, `yaml.load()` | Safe parsers and JSON |
| Broken TLS | `verify=False`, unverified SSL context | Keep certificate checks on |
| Weak cryptography | MD5, AES in ECB mode, 1024-bit RSA | PBKDF2, AES-GCM, 3072-bit RSA |
| Guessable tokens | `random.randint(...)` | `secrets.token_urlsafe()` |
| Secrets and access | Hard-coded password, unverified JWT, Flask debug on `0.0.0.0` | Environment variables, verified tokens, debug off |

## 1. Start SonarQube

```bash
docker compose --profile sonarqube up -d sonarqube
docker compose --profile sonarqube logs -f sonarqube
# wait for "SonarQube is operational" (about 2 minutes), then Ctrl+C
```

Open http://localhost:9000.

## 2. Log in and create a token

1. Log in as `admin` / `admin`, and set a new password when asked.
2. Avatar (top right) → **My Account** → **Security** → **Generate Tokens**: name `demo`, type **Global Analysis Token** → **Generate**.
3. Copy the token (it's shown only once) and keep it in your terminal:
   ```bash
   export SONAR_TOKEN=<your token>
   ```

## 3. Create a quality gate that checks all the code

SonarQube's default gate ("Sonar way") only checks *new* code, so a project's first scan always passes, however bad the code is. Create one that checks everything:

1. **Quality Gates** (top menu) → **Create** → name it `Workshop`.
2. Add these conditions, choosing **On Overall Code** each time:
   - **Security Rating** is worse than **A**
   - **Reliability Rating** is worse than **A**
   - **Security Hotspots Reviewed** is less than **100%**
3. Click **Set as Default**.

## 4. Scan the insecure code

```bash
docker compose --profile sonarqube run --rm -e SONAR_TOKEN sonar-scanner \
  -Dsonar.projectKey=lab2-start "-Dsonar.projectName=Lab 2 - Insecure code (start)" -Dsonar.sources=start
# expect: EXECUTION SUCCESS
```

The scanner reads the code and sends its findings to the server. Refresh http://localhost:9000: the project **Lab 2 - Insecure code (start)** shows **Failed**.

## 5. Read the results

Open the project and look at three things:

1. **Quality gate: Failed.** The verdict a pipeline uses to block a merge. It lists the conditions that failed.
2. **Issues** → filter by **Security**. These are confirmed vulnerabilities. Click one, such as the disabled certificate check or the unverified token: SonarQube highlights the exact line and explains the risk and how to fix it.
3. **Security Hotspots.** Code that *may* be dangerous, where only a person knows the context: `eval`, `shell=True`, MD5, the SQL query, `random`. Each one has a **Review** status waiting for a decision.

**Issue or hotspot?** An issue is a confirmed problem. A hotspot is risky code that needs a human decision, so SonarQube asks instead of guessing.

## 6. Scan the fixed code and review it

```bash
docker compose --profile sonarqube run --rm -e SONAR_TOKEN sonar-scanner \
  -Dsonar.projectKey=lab2-solution "-Dsonar.projectName=Lab 2 - Fixed code (solution)" -Dsonar.sources=solution
# expect: EXECUTION SUCCESS
```

Open **Lab 2 - Fixed code (solution)**:
- **No security issues:** every vulnerability is gone.
- **A few hotspots remain,** for example the `subprocess` call. Open each one, read the code, and set its status to **Safe** with a one-line reason, such as "fixed argument list, no shell".
- Refresh the project: the gate turns **Passed**. If it doesn't update, rerun the scan.

The fixed code also carries `# nosec` comments with written reasons. That's the same idea for command-line scanners: every exception is documented, so a reviewer can check it.

**Discuss:** who should be allowed to mark a hotspot Safe? Someone who understands the risk, with a written reason, like any other code review decision.

To see every fix line by line, compare the two files in VS Code: right-click `start/report_service.py` → **Select for Compare**, then right-click `solution/report_service.py` → **Compare with Selected**.

## 7. Clean up

```bash
docker compose --profile sonarqube stop sonarqube       # stop it, keep the projects
docker compose --profile sonarqube down -v              # or remove it and all its data
```

The lab files themselves are never changed, so there's nothing to reset.

## Takeaways
- Code review alone misses these bugs, because the code looks normal. A scanner checks every line, every time.
- Issues are confirmed problems; hotspots need a human decision, and recording that decision is part of the process.
- Teams run SonarQube on every pull request, and the quality gate can block a merge.
