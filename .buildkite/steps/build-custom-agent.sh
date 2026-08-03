#!/usr/bin/env bash
set -euo pipefail

readonly agent_revision="3ee0b89468d280228410016a5cb6d207c4959532"
readonly agent_tree="8dd2352c7566a39158a8d8d4f2e7de70000ffa4b"
readonly agent_patch="${BUILDKITE_BUILD_CHECKOUT_PATH:-${PWD}}/.buildkite/agent-systemd-watchdog.patch"
readonly output_path="${BUILDKITE_BUILD_CHECKOUT_PATH:-${PWD}}/build/buildkite-agent-linux-amd64"

agent_source_dir="$(mktemp -d)"
container_id=""
cleanup() {
  if [[ -n "${container_id}" ]]; then
    docker rm --force "${container_id}" >/dev/null 2>&1 || true
  fi
  rm -rf "${agent_source_dir}"
}
trap cleanup EXIT

echo "Building custom Buildkite agent from ${agent_revision}..."
git -C "${agent_source_dir}" init --quiet
git -C "${agent_source_dir}" remote add origin https://github.com/buildkite/agent.git
git -C "${agent_source_dir}" fetch --depth=1 origin "${agent_revision}"
git -C "${agent_source_dir}" checkout --quiet --detach FETCH_HEAD
git -C "${agent_source_dir}" apply --check "${agent_patch}"
git -C "${agent_source_dir}" apply "${agent_patch}"
git -C "${agent_source_dir}" add --all
if [[ "$(git -C "${agent_source_dir}" write-tree)" != "${agent_tree}" ]]; then
  echo "Custom agent patch did not produce the expected source tree" >&2
  exit 1
fi
chmod 0755 "${agent_source_dir}"

mkdir -p "$(dirname "${output_path}")"
container_id="$(docker create \
  --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  --env HOME=/tmp \
  --env GOCACHE=/tmp/go-build \
  --env GOBIN=/tmp/go/bin \
  --env GOPATH=/tmp/go \
  --env GOMODCACHE=/tmp/go-mod \
  --volume "${agent_source_dir}:/input:ro" \
  golang:1.26.5 \
  bash -euo pipefail -c '
    cp -a /input/. /tmp/agent
    cd /tmp/agent
    ./scripts/build-binary.sh linux amd64 sup-6917-watchdog
    ./pkg/buildkite-agent-linux-amd64 --version
  ')"
docker start --attach "${container_id}"
docker cp \
  "${container_id}:/tmp/agent/pkg/buildkite-agent-linux-amd64" \
  "${output_path}"
chmod 0755 "${output_path}"
