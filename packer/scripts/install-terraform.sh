#!/bin/bash

set -eu -o pipefail

TERRAFORM_VERSION=0.6.16
TERRAFORM_SHA256=e10987bca7ec15301bc2fd152795d51cfc9fdbe6c70c9708e6e2ed81eaa1f082

wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -O /tmp/terraform.zip
echo "$TERRAFORM_SHA256 /tmp/terraform.zip" | sha256sum --check --strict
sudo unzip /tmp/terraform.zip -d /usr/bin

