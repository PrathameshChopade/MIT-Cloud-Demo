#!/usr/bin/env bash
# Replaces the insecure Terraform with the fixed version and commits.
# Run inside the toolbox.
#
# Usage: apply-fixes.sh <directory>
set -eu

repo="${1:?Usage: apply-fixes.sh <directory>}"

cd "$repo"
cp /workspace/labs/lab3-ci-gate/solution/main.tf .
git add -A
git commit -qm "Fix infrastructure security findings"
echo "Fixes committed in $repo"
