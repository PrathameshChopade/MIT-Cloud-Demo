#!/usr/bin/env bash
# Builds the Git repo Jenkins builds from: the insecure Terraform, the
# Jenkinsfile and the must-fix check list. Run inside the toolbox.
#
# Usage: prepare-repo.sh <directory>
set -eu

repo="${1:?Usage: prepare-repo.sh <directory>}"
lab=/workspace/labs/lab3-ci-gate

if [ -e "$repo" ]; then
  echo "$repo already exists. Delete it first to start over." >&2
  exit 1
fi

mkdir -p "$repo"
cd "$repo"
git init -q
cp "$lab/start/main.tf" "$lab/Jenkinsfile" .
cp /etc/secure-path/checkov-baseline.yaml .
git add -A
git commit -qm "Order export service infrastructure"
echo "Repo ready at $repo"
