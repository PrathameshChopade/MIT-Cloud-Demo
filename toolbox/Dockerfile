# Toolbox for the "Securing the path to the cloud" session.
# Every scanner used in Labs 1-3, so participants install nothing else.
FROM debian:bookworm-slim

ARG GITLEAKS_VERSION=8.21.2
ARG TARGETARCH

# Use IPv4 for package downloads: on networks without IPv6 routing, apt
# otherwise keeps trying unreachable IPv6 mirrors and the build stalls.
RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4 \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git less nano python3 python3-venv tree \
 && rm -rf /var/lib/apt/lists/*

# Download the release and check it against the published checksums before
# installing it. Same lesson as the session: verify what you run.
RUN set -eu; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
      amd64) gl_arch=x64 ;; \
      arm64) gl_arch=arm64 ;; \
      *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    cd /tmp; \
    gl_base="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}"; \
    gl_file="gitleaks_${GITLEAKS_VERSION}_linux_${gl_arch}.tar.gz"; \
    curl -fsSLO "$gl_base/$gl_file"; \
    curl -fsSLO "$gl_base/gitleaks_${GITLEAKS_VERSION}_checksums.txt"; \
    grep " ${gl_file}\$" "gitleaks_${GITLEAKS_VERSION}_checksums.txt" | sha256sum -c -; \
    tar -xzf "$gl_file" -C /usr/local/bin gitleaks; \
    rm -rf /tmp/*

# Bandit and Checkov in separate virtualenvs so their dependencies can't clash.
RUN python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --no-cache-dir bandit==1.7.10 \
 && python3 -m venv /opt/checkov \
 && /opt/checkov/bin/pip install --no-cache-dir "checkov>=3.2,<3.3" \
 && ln -s /opt/venv/bin/bandit /usr/local/bin/bandit \
 && ln -s /opt/checkov/bin/checkov /usr/local/bin/checkov

RUN git config --system user.name "Workshop Participant" \
 && git config --system user.email "participant@example.com" \
 && git config --system init.defaultBranch main \
 && git config --system --add safe.directory '*'

COPY scripts/selftest.sh /usr/local/bin/selftest
COPY scripts/checkov-baseline.yaml /etc/secure-path/checkov-baseline.yaml
RUN chmod +x /usr/local/bin/selftest

WORKDIR /workspace
CMD ["bash"]
