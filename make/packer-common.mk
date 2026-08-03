SHELL = /bin/bash -o pipefail

PACKER_VERSION ?= 1.11.2

# Allow passing an existing golden base AMI into packer via `BASE_AMI_ID` env var
override BASE_AMI_ID ?=

# Set to true when building a stack image on top of a CIS-hardened base
IS_CIS ?= false

base_ami_from_output = $(shell \
  if [ -f $(1) ]; then \
    $(SED) -nE 's/^.*AMI: (ami-[a-z0-9]+).*$$/\1/p' $(1) | tail -n 1; \
  fi \
)

AWS_REGION ?= us-east-1

BUILDKITE_BUILD_NUMBER ?= none
BUILDKITE_PIPELINE_DEFAULT_BRANCH ?= main

# AMI visibility configuration
AMI_PUBLIC ?= false
AMI_USERS ?=

# Convert comma-separated AMI_USERS to JSON array format
AMI_USERS_LIST = $(if $(AMI_USERS),[$(shell echo '$(AMI_USERS)' | $(SED) 's/[[:space:]]//g' | $(SED) 's/[^,][^,]*/"&"/g')],[])

IS_RELEASED ?= false
ifeq ($(BUILDKITE_BRANCH),$(BUILDKITE_PIPELINE_DEFAULT_BRANCH))
	IS_RELEASED = true
endif
ifeq ($(BUILDKITE_BRANCH),$(BUILDKITE_TAG))
	IS_RELEASED = true
endif

SED ?= sed
ifeq ($(shell uname), Darwin)
	# Use GNU sed, not MacOS sed - required for extended regex support
	# BSD sed (default on macOS) doesn't support the regex patterns used in this Makefile
	SED = gsed
	ifeq ($(shell command -v gsed >/dev/null 2>&1 && echo yes || echo no), no)
    $(error GNU sed (gsed) is required on macOS but not found. Please install with: brew install gnu-sed)
	endif
endif
