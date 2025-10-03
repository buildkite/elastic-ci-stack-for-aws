#!/bin/bash
set -euo pipefail

# fetch_ssm_parameters fetches all SSM parameters under the given path and writes them to the given output file
fetch_ssm_parameters() {
  local ssm_path="$1"
  local output_file="$2"

  # check if the ssm_path is set
  if [[ -z "${ssm_path}" ]]; then
    echo "ssm_path is not set"
    return 1
  fi

  # check if the output_file is set
  if [[ -z "${output_file}" ]]; then
    echo "output_file is not set"
    return 1
  fi

  # trim off ssm: prefix
  ssm_path="${ssm_path//ssm:/}"

  aws ssm get-parameters-by-path \
    --path "${ssm_path}" \
    --recursive \
    --with-decryption \
    --query 'Parameters[*].{Name: Name, Value: Value}' --output json \
    | jq -r '.[] | [(.Name | split("/")[-1] | ascii_upcase), (["\"", .Value, "\""] | join(""))] | join("=")' \
      >"${output_file}"
}

FROM="$1"
TO="$2"

# Fetch content from various URI schemes:
# - s3://bucket/key: S3 object URI (uses AWS S3 API)
# - ssm:/path/to/param: SSM parameter path (uses AWS SSM API)
# - https://example.com/file: HTTPS URL (uses curl)
# - file:///path/to/file: Local file path (uses curl)
# - http://example.com/file: HTTP URL (uses curl)
case "$FROM" in
s3://*)
  # S3 object URI - use AWS CLI to fetch
  exec aws s3 cp "$FROM" "$TO"
  ;;
ssm:*)
  # SSM parameter path - fetch parameters recursively
  fetch_ssm_parameters "${FROM}" "${TO}"
  ;;
*)
  # All other URIs (HTTPS, HTTP, file://) - use curl
  exec curl -Lfs -o "$TO" "$FROM"
  ;;
esac
