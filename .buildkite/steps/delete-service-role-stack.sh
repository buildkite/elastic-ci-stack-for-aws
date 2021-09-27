#!/bin/bash
set -euo pipefail

service_role_stack="$(buildkite-agent meta-data get service-role-stack-name)"
if [ -n "${service_role_stack}" ]
then
	echo "--- Deleting service-role stack $service_role_stack"
	aws cloudformation delete-stack --stack-name "$service_role_stack"
	aws cloudformation wait stack-delete-complete --stack-name "$service_role_stack"
fi
