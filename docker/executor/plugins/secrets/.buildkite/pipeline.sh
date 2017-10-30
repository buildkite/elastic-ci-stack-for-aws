#!/bin/bash
set -eu

# If you build HEAD the pipeline.sh step, because it runs first, won't yet
# have the updated commit SHA. So we have to figure it out ourselves.
if [[ "${BUILDKITE_COMMIT:-HEAD}" == "HEAD" ]]; then
  commit=$(git show HEAD -s --pretty='%h')
else
  commit="${BUILDKITE_COMMIT}"
fi

# We have to use cat because pipeline.yml $ interpolation doesn't work in YAML
# keys, only values

cat <<YAML
steps:
  - label: ":bash: :hammer:"
    plugins:
      docker-compose#v1.3.2:
        run: tests

  - label: "㊙️ git-credentials test"
    command: .buildkite/test_credentials.sh
    plugins:
      s3-secrets#${commit}:
        bucket: buildkite-agents-elastic-secrets
YAML