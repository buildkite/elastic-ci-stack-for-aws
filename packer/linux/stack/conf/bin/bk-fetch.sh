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

  #
  # NOTE: The maximum number of parameters that can be retrieved is 25 to avoid throttling
  # in the case of misconfigured SSM path with a large number of child parameters
  aws ssm get-parameters-by-path \
    --path "${ssm_path}" \
    --recursive \
    --max-items 25 \
    --with-decryption \
    --query 'Parameters[*].{Name: Name, Value: Value}' --output json \
    | jq -r '.[] | [(.Name | split("/")[-1] | ascii_upcase), (["\"", .Value, "\""] | join(""))] | join("=")' \
      >"${output_file}"
}

FROM="$1"
TO="$2"

case "$FROM" in
s3://*)
  exec aws s3 cp "$FROM" "$TO"
  ;;
ssm:*)
  fetch_ssm_parameters "${FROM}" "${TO}"
  ;;
*)
  exec curl -Lfs -o "$TO" "$FROM"
  ;;
esac
