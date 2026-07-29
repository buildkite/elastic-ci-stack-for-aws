.PHONY: all clean build packer upload
.DEFAULT_GOAL := all

# Keep shared and platform-specific build settings outside this file so
# platform-only changes can be scoped correctly by Buildkite's if_changed rules.
include make/packer-common.mk
include make/packer-linux.mk
include make/packer-windows.mk
include make/stack.mk

all: packer build

# Remove any built cloudformation templates and packer output
clean:
	-rm -rf build/*
	-rm packer*.output

# Check for specific environment variables
env-%:
	@ if [ "${${*}}" = "" ]; then \
		echo "Environment variable $* not set"; \
		exit 1; \
	fi

# -----------------------------------------

build: packer build/mappings.yml build/aws-stack.yml

# -----------------------------------------

# Full images depend on base images when available
packer: packer-base-linux-amd64.output packer-base-linux-arm64.output packer-base-ubuntu2404-amd64.output packer-base-ubuntu2404-arm64.output packer-base-windows-amd64.output packer-linux-amd64.output packer-linux-arm64.output packer-ubuntu2404-amd64.output packer-ubuntu2404-arm64.output packer-windows-amd64.output

packer-fmt:
	docker run --rm -v "$(PWD):/src" -w /src "hashicorp/packer:full-$(PACKER_VERSION)" fmt -check -recursive packer/

build/mappings.yml: build/linux-amd64-ami.txt build/linux-arm64-ami.txt build/windows-amd64-ami.txt build/ubuntu2404-amd64-ami.txt build/ubuntu2404-arm64-ami.txt
	mkdir -p build
	printf "Mappings:\n  AWSRegion2AMI:\n    %q : { linuxamd64: %q, linuxarm64: %q, windows: %q, ubuntu2404amd64: %q, ubuntu2404arm64: %q }\n" \
		"$(AWS_REGION)" $$(cat build/linux-amd64-ami.txt) $$(cat build/linux-arm64-ami.txt) $$(cat build/windows-amd64-ami.txt) $$(cat build/ubuntu2404-amd64-ami.txt) $$(cat build/ubuntu2404-arm64-ami.txt) > $@

print-agent-versions:
	@echo Linux: $(CURRENT_AGENT_VERSION_LINUX)
	@echo Windows: $(CURRENT_AGENT_VERSION_WINDOWS)

# -----------------------------------------
# Cloudformation helpers

config.json:
	cp config.json.example config.json

SERVICE_ROLE=
ifdef SERVICE_ROLE
	role_arn="--role-arn=$(SERVICE_ROLE)"
endif

create-stack: build/aws-stack.yml env-STACK_NAME
	aws cloudformation create-stack \
		--output text \
		--stack-name $(STACK_NAME) \
		--disable-rollback \
		--template-body "file://$(PWD)/build/aws-stack.yml" \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
		--parameters "$$(cat config.json)" \
		"$(role_arn)"

update-stack: build/aws-stack.yml env-STACK_NAME
	aws cloudformation update-stack \
		--output text \
		--stack-name $(STACK_NAME) \
		--template-body "file://$(PWD)/build/aws-stack.yml" \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
		--parameters "$$(cat config.json)" \
		"$(role_arn)"

# -----------------------------------------
# Other

AGENT_VERSION ?= $(shell curl -Lfs "https://buildkite.com/agent/releases/latest?platform=linux&arch=amd64" | grep version | cut -d= -f2)

bump-agent-version:
	$(SED) -Ei "s/\[Buildkite Agent v.*\]/[Buildkite Agent v$(AGENT_VERSION)]/g" README.md
	$(SED) -Ei "s/AGENT_VERSION=.+/AGENT_VERSION=$(AGENT_VERSION)/g" packer/linux/scripts/install-buildkite-agent.sh
	$(SED) -Ei "s/\\\$$AGENT_VERSION = \".+\"/\$$AGENT_VERSION = \"$(AGENT_VERSION)\"/g" packer/windows/scripts/install-buildkite-agent.ps1

generate-toc:
	docker run -it --rm -v "$(PWD):/app" node:slim bash \
		-c "npm install -g markdown-toc && cd /app && markdown-toc -i README.md"
