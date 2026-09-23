#!/usr/bin/env bash
# Install Determinate Nix and point the host daemon at the Artifactory Nix caches.
set -euo pipefail

NIX_INSTALLER_VERSION="v3.21.0"
NIX_DAEMON_PROFILE=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
NETRC_CUSTOM=/etc/determinate/netrc.custom
CONFIG=/etc/determinate/config.json
CUSTOM_CONF=/etc/nix/nix.custom.conf
JFROG_SECRET_ID="${JFROG_SECRET_ID:-avp/jfrog/read_only_token}"
JFROG_SECRET_REGION="${JFROG_SECRET_REGION:-us-west-2}"

echo "Installing Determinate Nix ${NIX_INSTALLER_VERSION}..."
curl --proto '=https' --tlsv1.2 -sSf -L "https://install.determinate.systems/nix/tag/${NIX_INSTALLER_VERSION}" \
  | sudo sh -s -- install linux \
    --no-confirm \
    --init systemd

# shellcheck source=/dev/null
. "${NIX_DAEMON_PROFILE}"
echo "Nix installation complete: $(nix --version)"

[[ -f "${CUSTOM_CONF}" ]] || {
  echo "error: ${CUSTOM_CONF} not found after Determinate install" >&2
  exit 1
}

if ! grep -q appliedintuition.jfrog.io "${CUSTOM_CONF}"; then
  echo "Configuring Artifactory Nix substituters..."
  sudo tee -a "${CUSTOM_CONF}" >/dev/null <<'EOF'
extra-substituters = https://appliedintuition.jfrog.io/artifactory/api/nix/vos-test-nix-local?priority=1 https://appliedintuition.jfrog.io/artifactory/api/nix/shared-nix-central?priority=10
extra-trusted-public-keys = hephaestus-nix-cache-1:JvQt+Dxz1gl1rrPDzDaWSHk7zEgN7LreXX8ZsA9qHqY=
EOF
fi

echo "Fetching JFrog read-only token from Secrets Manager..."
secret_string=""
if ! secret_string=$(aws secretsmanager get-secret-value \
  --secret-id "${JFROG_SECRET_ID}" \
  --region "${JFROG_SECRET_REGION}" \
  --query SecretString \
  --output text 2>/dev/null); then
  echo "warning: could not read ${JFROG_SECRET_ID}; skipping Nix netrc setup"
  secret_string=""
fi

token=""
if [[ -n "${secret_string}" ]]; then
  if parsed=$(jq -er '.jfrog_token' <<<"${secret_string}" 2>/dev/null); then
    token="${parsed}"
  else
    token="${secret_string}"
  fi
fi

if [[ -n "${token}" ]]; then
  sudo install -d -m 0755 /etc/determinate
  printf 'machine appliedintuition.jfrog.io\nlogin read_only_user\npassword %s\n' "${token}" \
    | sudo tee "${NETRC_CUSTOM}" >/dev/null
  sudo chmod 0600 "${NETRC_CUSTOM}"

  if [[ ! -s "${CONFIG}" ]]; then
    sudo tee "${CONFIG}" >/dev/null <<EOF
{
  "authentication": {
    "additionalNetrcSources": ["${NETRC_CUSTOM}"]
  }
}
EOF
  elif ! grep -q "${NETRC_CUSTOM}" "${CONFIG}"; then
    echo "warning: ${CONFIG} exists without ${NETRC_CUSTOM}; not overwriting"
  fi
else
  echo "warning: no JFrog token available; Artifactory substituters will be unauthenticated"
fi

sudo systemctl restart nix-daemon.service
echo "Nix substituters: $(nix config show substituters)"
