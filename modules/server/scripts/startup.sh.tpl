#!/bin/bash
# Boot script for the server module (rendered by Terraform).
set -euo pipefail
exec > >(tee -a /var/log/server-startup.log) 2>&1
echo "== server startup $(date -u +%FT%TZ) =="

export DEBIAN_FRONTEND=noninteractive

retry() {
  local tries=$1
  shift
  local n=0
  until "$@"; do
    n=$((n + 1))
    if [ "$n" -ge "$tries" ]; then return 1; fi
    sleep $((n * 5))
  done
}

retry 5 apt-get update -y

%{ if install_docker ~}
retry 5 apt-get install -y --no-install-recommends docker.io docker-compose-v2
systemctl enable --now docker
%{ endif ~}

%{ if install_java ~}
retry 5 apt-get install -y --no-install-recommends openjdk-17-jdk
%{ endif ~}

%{ if install_maven ~}
retry 5 apt-get install -y --no-install-recommends maven
%{ endif ~}

%{ if register_as_gh_runner ~}
# ---- GitHub Actions runner registration ------------------------------------
retry 5 apt-get install -y --no-install-recommends curl jq git ca-certificates tar unzip

cat > /usr/local/bin/runner-common.sh <<'COMMON_EOF'
${common_script}
COMMON_EOF
chmod 0755 /usr/local/bin/runner-common.sh
# shellcheck disable=SC1091
source /usr/local/bin/runner-common.sh

RUNNER_USER=runner
RUNNER_DIR=/opt/actions-runner
id "$RUNNER_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$RUNNER_USER"
%{ if install_docker ~}
usermod -aG docker "$RUNNER_USER"
%{ endif ~}

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

cat > /usr/local/bin/runner-deregister.sh <<'DEREG_EOF'
#!/bin/bash
source /usr/local/bin/runner-common.sh
cd /opt/actions-runner || exit 0
./svc.sh stop || true
TOKEN=$(github_token remove) || exit 0
sudo -u runner ./config.sh remove --token "$TOKEN" || true
DEREG_EOF
chmod 0755 /usr/local/bin/runner-deregister.sh
%{ endif ~}

echo "== server startup complete =="
