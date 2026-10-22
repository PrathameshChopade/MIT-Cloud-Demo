# Local Jenkins for the CI gate demo, with Checkov installed.
# The setup wizard is disabled and there is no login: localhost only, never expose it.
FROM jenkins/jenkins:lts-jdk17

USER root
# Patient pip on slow networks (see toolbox/Dockerfile).
ENV PIP_DEFAULT_TIMEOUT=120 \
    PIP_RETRIES=10 \
    PIP_DISABLE_PIP_VERSION_CHECK=1
# Packages over HTTPS and IPv4 (see toolbox/Dockerfile).
RUN for f in /etc/apt/sources.list /etc/apt/sources.list.d/*; do \
      [ -f "$f" ] && sed -i 's|http://|https://|g' "$f"; \
    done; \
    echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4 \
 && apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-venv \
 && rm -rf /var/lib/apt/lists/* \
 && python3 -m venv /opt/checkov \
 && /opt/checkov/bin/pip install --no-cache-dir "checkov>=3.2,<3.3" \
 && ln -s /opt/checkov/bin/checkov /usr/local/bin/checkov \
 && git config --system --add safe.directory '*'

USER jenkins
RUN jenkins-plugin-cli --plugins workflow-aggregator git pipeline-stage-view
