#!/usr/bin/env bash
# Pre-session readiness check for macOS / Linux. Run from the repo folder:
#   bash verify.sh
ready=1

report() {
  if [ "$2" -eq 0 ]; then
    printf '  [OK]   %s\n' "$1"
  else
    printf '  [FAIL] %s - %s\n' "$1" "$3"
    ready=0
  fi
}

echo "Checking your machine"
command -v docker > /dev/null; report "Docker installed" $? "install Docker Desktop (or Docker Engine)"
command -v git > /dev/null;    report "Git installed" $? "install Git"
docker info > /dev/null 2>&1;  report "Docker running" $? "start Docker and wait until it is running"

docker image inspect secure-path-toolbox:1.0 > /dev/null 2>&1
report "Image secure-path-toolbox:1.0" $? "run 'docker compose build' in this folder"

if [ "$ready" -eq 1 ]; then
  docker compose run --rm toolbox selftest || ready=0
fi

if [ "$ready" -eq 1 ]; then
  echo
  echo "READY - see you at the session."
else
  echo
  echo "NOT READY - fix the items above, or send the output to the facilitator."
  exit 1
fi
