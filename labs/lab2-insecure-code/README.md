# Lab 2 — Insecure code (20 min, SonarQube walkthrough)

**Goal:** recognise the most common security bugs in ordinary-looking code, and see how a code-scanning platform, SonarQube, finds and reports them.

**The scenario:** an internal Python service builds, archives and shares customer reports. It works, it passed code review, and it contains about twenty security bugs.

**Where:** you read the code in **VS Code**. The facilitator shows SonarQube on screen. You don't need the toolbox for this lab.

## 1. Read the code

Open `labs/lab2-insecure-code/start/report_service.py` in VS Code. Each problem has a `RISK` comment explaining what an attacker could do and how it's fixed.

Before looking at SonarQube, count how many you would have caught in a code review.

## 2. The problems, grouped

| Problem | In the code | What an attacker can do | Fix |
|---|---|---|---|
| SQL injection | Customer ID pasted into the SQL text | Read every customer with one crafted ID | A parameterised query (`?`) |
| Command injection | `subprocess.run(..., shell=True)` | Run their own commands on the server | An argument list, no shell |
| Code execution | `eval()`, `pickle.loads()`, `yaml.load()` | Run any Python code they send | Safe parsers and JSON |
| Broken TLS | `verify=False`, unverified SSL context | Read or change traffic in transit | Keep certificate checks on |
| Weak cryptography | MD5, AES in ECB mode, 1024-bit RSA | Crack hashes, see patterns, break keys | PBKDF2, AES-GCM, 3072-bit RSA |
| Guessable tokens | `random.randint(...)` | Guess someone's session token | `secrets.token_urlsafe()` |
| Hard-coded password | `ADMIN_PASSWORD = "admin123"` | Read it from the repo | Environment variable or secrets manager |
| Unsafe files | `mktemp`, `chmod 777`, shared `/tmp` | Read, swap or change the files | `mkstemp`, owner-only permissions |
| Unverified tokens | JWT decoded without its signature | Forge a token claiming to be admin | Verify with the key and allowed algorithms |
| Exposed debug server | Flask `debug=True` on `0.0.0.0` | Run code through the debug console | Debug off, listen on localhost only |

## 3. The same code in SonarQube (facilitator demo)

The facilitator has scanned two projects: the insecure `start` code and the fixed `solution` code. On screen you'll see:

1. **The quality gate:** the pass/fail verdict for the whole project. The insecure version **fails**.
2. **Issues:** confirmed bugs and vulnerabilities, each pointing at the exact line with an explanation. For example, certificate checks turned off.
3. **Security hotspots:** risky code a person must review, such as `eval`, `shell=True` or MD5. It may be safe in context, or it may not.
4. **Review:** in the fixed project, the facilitator marks the remaining hotspots **Safe** with a reason, and the gate turns **Passed**. The decision is recorded for audit.

## 4. Compare with the fixed version

In VS Code: right-click `start/report_service.py` → **Select for Compare**, then right-click `solution/report_service.py` → **Compare with Selected**.

Notice the `# nosec` comments in the solution. Each one is a documented exception with a written reason, so a reviewer can see why a warning was accepted. An exception with no reason should be challenged in review.

## Takeaways
- Code review alone misses these bugs, because the code looks normal. A scanner checks every line, every time.
- Hotspots need a human decision; recording that decision is part of the process.
- Tools like SonarQube run on every pull request, and the quality gate can block a merge.
