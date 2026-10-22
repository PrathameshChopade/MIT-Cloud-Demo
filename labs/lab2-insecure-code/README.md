# Lab 2 — Insecure code (20 min)

**Goal:** recognise the most common security bugs in ordinary-looking code, understand what an attacker can do with each one, and see how a code-scanning platform, SonarQube, finds and reports them.

**The scenario:** an internal Python service builds, archives and shares customer reports. It works, it passed code review, and it contains about twenty security bugs. How many would your code review catch?

**Real-world context:** in 2023, a single SQL injection bug in the MOVEit file-transfer product let attackers steal data from thousands of organisations. Injection flaws have appeared in every OWASP Top 10 list since it began in 2003.

**Where:** you read the code in **VS Code**; the facilitator runs SonarQube on screen. You don't need the toolbox for this lab.
**In your editor:** open `labs/lab2-insecure-code/start/report_service.py`, and `labs/lab2-insecure-code/solution/report_service.py` beside it.

## 1. Read the code (5 min)

Open `start/report_service.py`. Each function is a few lines long and looks normal. Every bug is marked with a `RISK` comment (what an attacker can do) and a `FIX` comment (how the fixed version avoids it).

Before reading the comments, **count how many problems you would have caught in a code review.** Most people find the hard-coded password and `eval()`, and few spot the predictable token or the unverified TLS connection.

## 2. A closer look at four bugs

### SQL injection: `find_customer`

```python
# start/report_service.py
conn.execute(f"SELECT name, email FROM customers WHERE id = '{customer_id}'")
```

**The attack:** send the customer ID `x' OR '1'='1`. The query becomes `... WHERE id = 'x' OR '1'='1'`, which is true for every row, so **every customer is returned**.

```python
# solution/report_service.py
conn.execute("SELECT name, email FROM customers WHERE id = ?", (customer_id,))
```

**The fix:** a parameterised query. The database receives the ID separately, as data, so it can never become part of the SQL.

### Command injection: `archive_report`

```python
# start/report_service.py
subprocess.run(f"tar -czf /tmp/{filename}.tar.gz reports/{filename}", shell=True)
```

**The attack:** send the filename `x; rm -rf /`. With `shell=True` the whole text goes to a shell, which runs `tar`, then **runs the attacker's command**.

```python
# solution/report_service.py
name = Path(filename).name  # drops any "../" or "; rm -rf" tricks
ARCHIVE_DIR.mkdir(exist_ok=True)
subprocess.run(  # nosec B603 B607 - fixed argument list, no shell
    ["tar", "-czf", str(ARCHIVE_DIR / f"{name}.tar.gz"), "-C", "reports", name],
    check=True,
)
```

**The fix:** pass a list of arguments, with no shell, so the filename is only ever a filename. Keep only the file's own name, and write to a dedicated folder instead of the shared `/tmp`.

### Running code you were sent: `calculate`

```python
# start/report_service.py
def calculate(expression):
    return eval(expression)        # meant for totals like "120 * 3"
```

**The attack:** send `__import__('os').system('cat /etc/passwd')` instead of a sum. `eval()` runs any Python, so **the server runs it**.

```python
# solution/report_service.py
def calculate(left, op, right):
    return OPERATIONS[op](float(left), float(right))   # only + - * /
```

**The fix:** accept only what the feature needs, here four operations on two numbers. Anything else raises an error.

### Guessable session tokens: `new_session_token`

```python
# start/report_service.py
return str(random.randint(100000, 999999))
```

**The attack:** Python's `random` is predictable by design, and a 6-digit number has only 900,000 possible values. An attacker can **guess a valid token and take over someone's session**.

```python
# solution/report_service.py
return secrets.token_urlsafe(32)
```

**The fix:** the `secrets` module, which is designed for security and produces a 43-character random token.

## 3. All the problems in the file

| Problem | In the code | What an attacker can do | Fix |
|---|---|---|---|
| SQL injection | Customer ID pasted into the SQL text | Read every customer with one crafted ID | A parameterised query (`?`) |
| Command injection | `subprocess.run(..., shell=True)` | Run their own commands on the server | An argument list, no shell |
| Code execution | `eval()`, `pickle.loads()`, `yaml.load()` | Run any Python code they send | Safe parsers and JSON |
| Broken TLS | `verify=False`, unverified SSL context | Read or change traffic in transit | Keep certificate checks on |
| Weak cryptography | MD5, AES in ECB mode, 1024-bit RSA | Crack hashes, see patterns, break keys | PBKDF2, AES-GCM, 3072-bit RSA |
| Guessable tokens | `random.randint(...)` | Guess someone's session token | `secrets.token_urlsafe()` |
| Hard-coded password | `ADMIN_PASSWORD = "admin123"` | Read it from the repo | Environment variable or secrets manager |
| Timing leak | `password == ADMIN_PASSWORD` | Work out the password from response times | `secrets.compare_digest()` |
| Unsafe files | `mktemp`, `chmod 777`, shared `/tmp` | Read, swap or change the files | `mkstemp`, owner-only permissions |
| Unverified tokens | JWT decoded without its signature | Forge a token claiming to be admin | Verify with the key and allowed algorithms |
| Exposed debug server | Flask `debug=True` on `0.0.0.0` | Run code through the debug console | Debug off, listen on localhost only |

## 4. The same code in SonarQube (facilitator demo)

**SonarQube** is a code-scanning platform that many teams run on every pull request. It reads the code without running it, reports problems with explanations, keeps a history, and gives each project a pass/fail **quality gate**.

The facilitator has scanned both versions of the file as two projects. On screen you'll see:

1. **Projects:** `Lab 2 - Insecure code (start)` shows **Failed**; `Lab 2 - Fixed code (solution)` sits beside it.
2. **Issues** (start project, filtered by **Security**): confirmed vulnerabilities, each pointing at the exact line with an explanation of the risk and the fix. For example, the disabled certificate check and the unverified token.
3. **Security hotspots:** code that *may* be dangerous and needs a person to decide, such as `eval`, `shell=True`, MD5, the SQL query and `random`.
4. **Review, live** (solution project): the remaining hotspots, such as the safe `subprocess` call, are opened, read, and marked **Safe** with a one-line reason. The gate turns **Passed**, and the decision is recorded for audit.

**Discuss:**
- **Issue or hotspot?** An issue is a confirmed problem. A hotspot is risky code where only a human knows the context, so SonarQube asks for a decision instead of guessing.
- **Who should mark hotspots Safe?** Someone who understands the risk, with a written reason, the same as any other code review decision.

## 5. Compare with the fixed version

In VS Code: right-click `start/report_service.py` → **Select for Compare**, then right-click `solution/report_service.py` → **Compare with Selected**. Every change is a fix for one of the problems in the table.

Notice the `# nosec` comments in the solution, for example:

```python
import subprocess  # nosec B404 - only called below with a fixed argument list and no shell
```

Each one is a documented exception with a written reason, so a reviewer can see why a warning was accepted. An exception with no reason should be challenged in review.

## 6. Run it yourself (optional, after the session)

To repeat the SonarQube part on your own laptop (it needs about 3 GB of free memory), from the repo folder:

```bash
docker compose --profile sonarqube up -d sonarqube
docker compose --profile sonarqube logs -f sonarqube    # wait for "SonarQube is operational", then Ctrl+C
```

1. Open http://localhost:9000, log in as `admin` / `admin`, and set a new password.
2. Avatar → **My Account** → **Security** → **Generate Tokens**: type **Global Analysis Token**. Copy it.
3. Scan both versions:
   ```bash
   export SONAR_TOKEN=<your token>
   docker compose --profile sonarqube run --rm -e SONAR_TOKEN sonar-scanner \
     -Dsonar.projectKey=lab2-start "-Dsonar.projectName=Lab 2 - Insecure code (start)" -Dsonar.sources=start
   docker compose --profile sonarqube run --rm -e SONAR_TOKEN sonar-scanner \
     -Dsonar.projectKey=lab2-solution "-Dsonar.projectName=Lab 2 - Fixed code (solution)" -Dsonar.sources=solution
   ```
   Each scan ends with `EXECUTION SUCCESS`. Refresh http://localhost:9000 to see both projects.

SonarQube's default quality gate only checks *new* code, so a project's first scan always passes. To see the insecure version fail, create a gate that checks overall code first (FACILITATOR.md, "Lab 2 SonarQube demo setup", step 4).

## 7. Clean up

```bash
docker compose --profile sonarqube stop sonarqube       # stop it, keep the projects
docker compose --profile sonarqube down -v              # or remove it and all its data
```

The lab files themselves are never changed, so there's nothing to reset.

## Takeaways
- The most dangerous bugs are well-known patterns: injection, running untrusted input, broken TLS, weak crypto, predictable randomness.
- Code review alone misses them, because the code looks normal. A scanner checks every line, every time.
- Hotspots need a human decision, and recording that decision is part of the process.
- Tools like SonarQube run on every pull request, and the quality gate can block a merge.
