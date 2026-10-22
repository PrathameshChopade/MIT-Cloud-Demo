# Local Jenkins for the CI gate demo, with Checkov installed.
# The setup wizard is disabled and there is no login: localhost only, never expose it.
FROM jenkins/jenkins:lts-jdk17

USER root
# IPv4 for package downloads (see toolbox/Dockerfile).
RUN echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4 \
 && apt-get update \
 && apt-get install -y --no-install-recommends python3 python3-venv \
 && rm -rf /var/lib/apt/lists/* \
 && python3 -m venv /opt/checkov \
 && /opt/checkov/bin/pip install --no-cache-dir "checkov>=3.2,<3.3" \
 && ln -s /opt/checkov/bin/checkov /usr/local/bin/checkov \
 && git config --system --add safe.directory '*'

USER jenkins
RUN jenkins-plugin-cli --plugins workflow-aggregator git pipeline-stage-view
