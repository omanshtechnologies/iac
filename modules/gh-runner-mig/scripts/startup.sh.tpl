#!/bin/bash
# Boot script for a GitHub Actions runner VM (rendered by Terraform).
set -euo pipefail
exec > >(tee -a /var/log/runner-startup.log) 2>&1
echo "== runner startup $(date -u +%FT%TZ) =="

export DEBIAN_FRONTEND=noninteractive
RUNNER_USER=runner
RUNNER_DIR=/opt/actions-runner

# ---- helpers ---------------------------------------------------------------
cat > /usr/local/bin/runner-common.sh <<'COMMON_EOF'
${common_script}
COMMON_EOF
chmod 0755 /usr/local/bin/runner-common.sh
# shellcheck disable=SC1091
source /usr/local/bin/runner-common.sh

# ---- packages --------------------------------------------------------------
retry 5 apt-get update -y
retry 5 apt-get install -y --no-install-recommends curl jq git ca-certificates tar unzip build-essential
%{ if install_docker ~}
retry 5 apt-get install -y docker.io
%{ endif ~}
%{ if install_ops_agent ~}
curl -sSf https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh -o /tmp/ops-agent.sh \
  && bash /tmp/ops-agent.sh --also-install || echo "WARN: ops agent install failed (continuing)"
%{ endif ~}

# ---- runner user (non-root, no sudo) ----------------------------------------
id "$RUNNER_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$RUNNER_USER"
%{ if install_docker ~}
usermod -aG docker "$RUNNER_USER"
%{ endif ~}

# ---- runner binaries ---------------------------------------------------------
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"
if [ ! -x ./config.sh ]; then
  retry 5 curl -sSfL -o runner.tgz \
    "https://github.com/actions/runner/releases/download/v${runner_version}/actions-runner-linux-x64-${runner_version}.tar.gz"
  tar xzf runner.tgz
  rm -f runner.tgz
  ./bin/installdependencies.sh
fi
chown -R "$RUNNER_USER":"$RUNNER_USER" "$RUNNER_DIR"

# ---- register ---------------------------------------------------------------
REG_TOKEN=$(retry 5 github_token registration) || { echo "ERROR: could not get registration token"; exit 1; }
[ -n "$REG_TOKEN" ] && [ "$REG_TOKEN" != "null" ] || { echo "ERROR: empty registration token"; exit 1; }

sudo -u "$RUNNER_USER" ./config.sh --unattended --replace \
  --url "${github_url}" \
  --token "$REG_TOKEN" \
  --name "${runner_name}-$(hostname)" \
  --labels "${runner_labels}" \
  --work _work
unset REG_TOKEN

./svc.sh install "$RUNNER_USER"
./svc.sh start

# ---- deregister on shutdown (used by the shutdown-script metadata) ---------------
cat > /usr/local/bin/runner-deregister.sh <<'DEREG_EOF'
#!/bin/bash
source /usr/local/bin/runner-common.sh
cd /opt/actions-runner || exit 0
./svc.sh stop || true
TOKEN=$(github_token remove) || exit 0
sudo -u runner ./config.sh remove --token "$TOKEN" || true
DEREG_EOF
chmod 0755 /usr/local/bin/runner-deregister.sh

echo "== runner startup complete =="
