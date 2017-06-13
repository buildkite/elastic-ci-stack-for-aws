#!/bin/bash
set -eu

echo "--- Deleting stack $AWS_STACK_NAME"
aws cloudformation delete-stack --stack-name "$AWS_STACK_NAME"