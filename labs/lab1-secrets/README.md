# Lab 1 — Secrets in Git (15 min)

**Goal:** see how easily credentials leak through Git, why deleting them doesn't help, and how to stop them before they're committed.

**The scenario:** a developer in a hurry hard-codes an AWS access key and a database password into a small service, and commits it. A week later, they "fix" it by deleting the lines and committing again. Is the key safe now?

**Real-world context:** In 2016, Uber's AWS credentials were found in a *private* GitHub repo, which gave the attackers access to data on 57 million users. Toyota had an access key in a public repo for about five years (disclosed in 2022).

**Where:** in the **toolbox** (`docker compose run --rm toolbox`), which starts in the repo folder.
**In your editor:** open `labs/lab1-secrets/start/app/config.py`. The keys in it are fake.

## 1. Commit the service as a developer in a hurry would

```bash
cd labs/lab1-secrets/start
cat app/config.py                 # fake AWS keys and a database password
git init -q && git add . && git commit -qm "Add order export service"
```

This creates a small Git repository just for this lab, inside `labs/lab1-secrets/start`.

## 2. Scan the repository

```bash
gitleaks git -v                   # expect: "leaks found", with file, line, commit and rule
```

Notice that gitleaks reports the file, the line, the commit and the rule that matched (for example, `aws-access-token`).

## 3. "Fix" it by deleting the secrets

```bash
cp -r ../solution/. .
cat app/config.py                 # now reads from environment variables
git add -A && git commit -qm "Move secrets to environment variables"

gitleaks dir .                    # expect: "no leaks found" in the current files
gitleaks git -v                   # expect: leaks STILL found, in the first commit
git show HEAD~1:app/config.py     # the key is still in history
```

**Discuss:** once a secret has been pushed, treat it as compromised.
1. **Rotate it first:** revoke the key and issue a new one.
2. **Then clean up:** rewrite history with `git filter-repo` or BFG. Clones, forks, CI caches and backups may still have copies, so rewriting history alone doesn't make the key safe again.

## 4. Stop it before it happens: a pre-commit hook

```bash
cat > .git/hooks/pre-commit <<'EOF'
#!/bin/sh
# Block any commit that contains a secret.
exec gitleaks git --pre-commit --staged --redact -v
EOF
chmod +x .git/hooks/pre-commit

echo 'BACKUP_KEY = "AKIARZ5TQW7XKMB3NPLD"' > app/backup.py
git add app/backup.py
git commit -m "Add backup job"    # expect: blocked, "leaks found"
git log --oneline                 # expect: still only 2 commits
```

**Discuss:** anyone can skip the hook with `git commit --no-verify`, and each developer has to install it themselves. That's why teams also run the same check in their CI pipeline, where it can't be skipped. Lab 3 shows such a pipeline gate.

## 5. Reset the lab

Puts `labs/lab1-secrets/start` back exactly as it was in the repo:

```bash
cd /workspace
rm -rf labs/lab1-secrets/start/.git
git restore labs/lab1-secrets && git clean -fdq labs/lab1-secrets
```

## Takeaways
- Scan the whole Git history, not just the current files.
- A leaked secret has to be rotated. Removing it from the code isn't enough.
- The best fix is having no long-lived keys at all: use IAM roles, a secrets manager, or short-lived credentials.
