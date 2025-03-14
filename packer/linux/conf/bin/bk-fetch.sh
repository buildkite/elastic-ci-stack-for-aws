#!/bin/bash
set -euo pipefail

# fetch_ssm_parameters fetches all SSM parameters under the given path and writes them to the given output file
fetch_ssm_parameters() {
  local ssm_path="$1"
  local output_file="$2"

  # check if the ssm_path is set
  if [ -z "$ssm_path" ]; then
    echo "ssm_path is not set"
    return 1
  fi

  # check if the output_file is set
  if [ -z "$output_file" ]; then
    echo "output_file is not set"
    return 1
  fi

  # trim off ssm: prefix
  ssm_path=${ssm_path//ssm:/}

  # Get all SSM parameter names under the given path
  #
  # NOTE: The maximum number of parameters that can be retrieved is 25 to avoid throttling
  # in the case of misconfigured SSM path with a large number of child parameters
  local ssm_parameter_names
  ssm_parameter_names=$(aws ssm get-parameters-by-path \
    --path "$ssm_path" \
    --recursive \
    --max-items 25 \
    --with-decryption \
    --query 'Parameters[].Name' \
    --output text)

  # Loop through each parameter and export it as an environment variable
  for name in $ssm_parameter_names; do
    local value
    value=$(aws ssm get-parameter \
      --name "$name" \
      --with-decryption \
      --query 'Parameter.Value' \
      --output text)
    if [ -n "$name" ] && [ -n "$value" ]; then
      local var_name
      var_name=$(echo "$name" | awk -F/ '{print toupper($NF)}')
      echo "Exported variable: $var_name"
      echo "$var_name=$value" >>"$output_file"
    fi
  done
}

FROM="$1"
TO="$2"

case "$FROM" in
s3://*)
  exec aws s3 cp "$FROM" "$TO"
  ;;
ssm:*)
  fetch_ssm_parameters "$FROM" "$TO"
  ;;
*)
  exec curl -Lfs -o "$TO" "$FROM"
  ;;
esac
