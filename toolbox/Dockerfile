# Toolbox for the "Securing the path to the cloud" session: gitleaks (Lab 1)
# and Checkov (Lab 3).
#
# Built on Checkov's official image, so Checkov arrives ready-made: installing
# it with pip downloads hundreds of packages and fails on slow networks. The
# image already has Git and Python, so nothing else is installed with apt or pip.
FROM bridgecrew/checkov:3.3.26

ARG GITLEAKS_VERSION=8.21.2
ARG TARGETARCH

# gitleaks: download the release, check it against the published checksums,
# then install it. Same lesson as the session: verify what you run.
RUN python3 - <<'EOF'
import hashlib, os, platform, tarfile, urllib.request

version = os.environ["GITLEAKS_VERSION"]
machine = os.environ.get("TARGETARCH") or platform.machine()
arch = {"amd64": "x64", "x86_64": "x64", "arm64": "arm64", "aarch64": "arm64"}[machine]
base = f"https://github.com/gitleaks/gitleaks/releases/download/v{version}"
name = f"gitleaks_{version}_linux_{arch}.tar.gz"

def fetch(url):
    return urllib.request.urlopen(url, timeout=120).read()

data = fetch(f"{base}/{name}")
sums = fetch(f"{base}/gitleaks_{version}_checksums.txt").decode()
expected = next(line.split()[0] for line in sums.splitlines() if line.split()[-1] == name)
if hashlib.sha256(data).hexdigest() != expected:
    raise SystemExit("gitleaks checksum mismatch: refusing to install")

with open("/tmp/gitleaks.tar.gz", "wb") as f:
    f.write(data)
with tarfile.open("/tmp/gitleaks.tar.gz") as tar:
    tar.extract("gitleaks", "/usr/local/bin", filter="data")
os.chmod("/usr/local/bin/gitleaks", 0o755)
os.remove("/tmp/gitleaks.tar.gz")
print(f"gitleaks {version} ({arch}) verified and installed")
EOF

RUN git config --system user.name "Workshop Participant" \
 && git config --system user.email "participant@example.com" \
 && git config --system init.defaultBranch main \
 && git config --system --add safe.directory '*'

COPY scripts/selftest.sh /usr/local/bin/selftest
COPY scripts/checkov-baseline.yaml /etc/secure-path/checkov-baseline.yaml
RUN chmod +x /usr/local/bin/selftest

# The Checkov image starts Checkov by default; the toolbox starts a shell.
ENTRYPOINT []
WORKDIR /workspace
CMD ["bash"]
