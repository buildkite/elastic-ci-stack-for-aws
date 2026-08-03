PACKER_LINUX_BASE_FILES = $(shell find packer/linux/base packer/linux/shared)
PACKER_LINUX_STACK_FILES = $(shell find packer/linux/stack packer/linux/shared)

BASE_AMI_ID_LINUX_AMD64 ?= $(call base_ami_from_output,packer-base-linux-amd64.output)
BASE_AMI_ID_LINUX_ARM64 ?= $(call base_ami_from_output,packer-base-linux-arm64.output)
BASE_AMI_ID_UBUNTU2404_AMD64 ?= $(call base_ami_from_output,packer-base-ubuntu2404-amd64.output)
BASE_AMI_ID_UBUNTU2404_ARM64 ?= $(call base_ami_from_output,packer-base-ubuntu2404-arm64.output)

GO_VERSION ?= 1.26.1

FIXPERMS_FILES = go.mod go.sum $(shell find internal/fixperms)

# goss is pinned to a commit (see versions.sh) until the upstream fix is
# released. Read the pin from versions.sh.
GOSS_VERSIONS_FILE = packer/linux/base/scripts/versions.sh
GOSS_COMMIT = $(shell . $(GOSS_VERSIONS_FILE) && echo $$GOSS_COMMIT)
GOSS_VERSION = $(shell . $(GOSS_VERSIONS_FILE) && echo $$GOSS_VERSION)

ARM64_INSTANCE_TYPE ?= m7g.xlarge
AMD64_INSTANCE_TYPE ?= m7a.xlarge

# Build a mapping file for a single region and image id pair
mappings-for-linux-amd64-image: env-AWS_REGION env-IMAGE_ID
	mkdir -p build/
	printf "Mappings:\n  AWSRegion2AMI:\n    %s: { linuxamd64: %s, linuxarm64: '', windows: '', ubuntu2404amd64: '', ubuntu2404arm64: '' }\n" \
		"$(AWS_REGION)" $(IMAGE_ID) > build/mappings.yml

# Build a mapping file for a single region and image id pair
mappings-for-linux-arm64-image: env-AWS_REGION env-IMAGE_ID
	mkdir -p build/
	printf "Mappings:\n  AWSRegion2AMI:\n    %s: { linuxamd64: '', linuxarm64: %s, windows: '', ubuntu2404amd64: '', ubuntu2404arm64: '' }\n" \
		"$(AWS_REGION)" $(IMAGE_ID) > build/mappings.yml

# Build an ubuntu2404 mapping file for a single region and image id pair
mappings-for-ubuntu2404-amd64-image: env-AWS_REGION env-IMAGE_ID
	mkdir -p build/
	printf "Mappings:\n  AWSRegion2AMI:\n    %s: { linuxamd64: '', linuxarm64: '', windows: '', ubuntu2404amd64: %s, ubuntu2404arm64: '' }\n" \
		"$(AWS_REGION)" $(IMAGE_ID) > build/mappings.yml

# Build an ubuntu2404 mapping file for a single region and image id pair
mappings-for-ubuntu2404-arm64-image: env-AWS_REGION env-IMAGE_ID
	mkdir -p build/
	printf "Mappings:\n  AWSRegion2AMI:\n    %s: { linuxamd64: '', linuxarm64: '', windows: '', ubuntu2404amd64: '', ubuntu2404arm64: %s }\n" \
		"$(AWS_REGION)" $(IMAGE_ID) > build/mappings.yml

build/linux-amd64-ami.txt: packer-linux-amd64.output env-AWS_REGION
	mkdir -p build
	grep -Eo "$(AWS_REGION): (ami-.+)" $< | cut -d' ' -f2 | xargs echo -n > $@

# Build linux packer image
packer-linux-amd64.output: $(PACKER_LINUX_STACK_FILES) build/fix-perms-linux-amd64 build/goss-linux-amd64 $(if $(strip $(BASE_AMI_ID)),,packer-base-linux-amd64.output)
	docker run \
		-e AWS_DEFAULT_REGION  \
		-e AWS_PROFILE \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e PACKER_LOG \
		-v ${HOME}/.aws:/root/.aws \
		-v "$(PWD):/src" \
		--rm \
		-w /src/packer/linux/stack \
		hashicorp/packer:full-$(PACKER_VERSION) build -timestamp-ui \
			-var 'region=$(AWS_REGION)' \
			-var 'arch=x86_64' \
			-var 'instance_type=$(AMD64_INSTANCE_TYPE)' \
			-var 'build_number=$(BUILDKITE_BUILD_NUMBER)' \
			-var 'is_released=$(IS_RELEASED)' \
			-var 'ami_public=$(AMI_PUBLIC)' \
			-var 'ami_users=$(AMI_USERS_LIST)' \
			-var 'base_ami_id=$(if $(BASE_AMI_ID),$(BASE_AMI_ID),$(BASE_AMI_ID_LINUX_AMD64))' \
			-var 'is_cis=$(IS_CIS)' \
			buildkite-ami.pkr.hcl | tee $@

build/linux-arm64-ami.txt: packer-linux-arm64.output env-AWS_REGION
	mkdir -p build
	grep -Eo "$(AWS_REGION): (ami-.+)" $< | cut -d' ' -f2 | xargs echo -n > $@

# NOTE: make removes the $ escapes, everything else is passed to the shell
CURRENT_AGENT_VERSION_LINUX ?= $(shell $(SED) -En 's/^AGENT_VERSION="(.+?)"$$/\1/p' packer/linux/stack/scripts/install-buildkite-agent.sh)

# Build linuxarm64 packer image
packer-linux-arm64.output: $(PACKER_LINUX_STACK_FILES) build/fix-perms-linux-arm64 build/goss-linux-arm64 $(if $(strip $(BASE_AMI_ID)),,packer-base-linux-arm64.output)
	@echo Agent Version: $(CURRENT_AGENT_VERSION_LINUX)
	docker run \
		-e AWS_DEFAULT_REGION  \
		-e AWS_PROFILE \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e PACKER_LOG \
		-v ${HOME}/.aws:/root/.aws \
		-v "$(PWD):/src" \
		--rm \
		-w /src/packer/linux/stack \
		hashicorp/packer:full-$(PACKER_VERSION) build -timestamp-ui \
			-var 'region=$(AWS_REGION)' \
			-var 'arch=arm64' \
			-var 'instance_type=$(ARM64_INSTANCE_TYPE)' \
			-var 'build_number=$(BUILDKITE_BUILD_NUMBER)' \
			-var 'is_released=$(IS_RELEASED)' \
			-var 'agent_version=$(CURRENT_AGENT_VERSION_LINUX)' \
			-var 'ami_public=$(AMI_PUBLIC)' \
			-var 'ami_users=$(AMI_USERS_LIST)' \
			-var 'base_ami_id=$(if $(BASE_AMI_ID),$(BASE_AMI_ID),$(BASE_AMI_ID_LINUX_ARM64))' \
			buildkite-ami.pkr.hcl | tee $@

build/ubuntu2404-amd64-ami.txt: packer-ubuntu2404-amd64.output env-AWS_REGION
	mkdir -p build
	grep -Eo "$(AWS_REGION): (ami-.+)" $< | cut -d' ' -f2 | xargs echo -n > $@

# Build ubuntu2404 amd64 packer image (reuses packer/linux/stack via os_distro)
packer-ubuntu2404-amd64.output: $(PACKER_LINUX_STACK_FILES) build/fix-perms-linux-amd64 build/goss-linux-amd64 $(if $(strip $(BASE_AMI_ID)),,packer-base-ubuntu2404-amd64.output)
	@echo Agent Version: $(CURRENT_AGENT_VERSION_LINUX)
	docker run \
		-e AWS_DEFAULT_REGION  \
		-e AWS_PROFILE \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e PACKER_LOG \
		-v ${HOME}/.aws:/root/.aws \
		-v "$(PWD):/src" \
		--rm \
		-w /src/packer/linux/stack \
		hashicorp/packer:full-$(PACKER_VERSION) build -timestamp-ui \
			-var 'region=$(AWS_REGION)' \
			-var 'arch=x86_64' \
			-var 'os_distro=ubuntu2404' \
			-var 'instance_type=$(AMD64_INSTANCE_TYPE)' \
			-var 'build_number=$(BUILDKITE_BUILD_NUMBER)' \
			-var 'is_released=$(IS_RELEASED)' \
			-var 'agent_version=$(CURRENT_AGENT_VERSION_LINUX)' \
			-var 'ami_public=$(AMI_PUBLIC)' \
			-var 'ami_users=$(AMI_USERS_LIST)' \
			-var 'base_ami_id=$(if $(BASE_AMI_ID),$(BASE_AMI_ID),$(BASE_AMI_ID_UBUNTU2404_AMD64))' \
			buildkite-ami.pkr.hcl | tee $@

build/ubuntu2404-arm64-ami.txt: packer-ubuntu2404-arm64.output env-AWS_REGION
	mkdir -p build
	grep -Eo "$(AWS_REGION): (ami-.+)" $< | cut -d' ' -f2 | xargs echo -n > $@

# Build ubuntu2404 arm64 packer image (reuses packer/linux/stack via os_distro)
packer-ubuntu2404-arm64.output: $(PACKER_LINUX_STACK_FILES) build/fix-perms-linux-arm64 build/goss-linux-arm64 $(if $(strip $(BASE_AMI_ID)),,packer-base-ubuntu2404-arm64.output)
	@echo Agent Version: $(CURRENT_AGENT_VERSION_LINUX)
	docker run \
		-e AWS_DEFAULT_REGION  \
		-e AWS_PROFILE \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e PACKER_LOG \
		-v ${HOME}/.aws:/root/.aws \
		-v "$(PWD):/src" \
		--rm \
		-w /src/packer/linux/stack \
		hashicorp/packer:full-$(PACKER_VERSION) build -timestamp-ui \
			-var 'region=$(AWS_REGION)' \
			-var 'arch=arm64' \
			-var 'os_distro=ubuntu2404' \
			-var 'instance_type=$(ARM64_INSTANCE_TYPE)' \
			-var 'build_number=$(BUILDKITE_BUILD_NUMBER)' \
			-var 'is_released=$(IS_RELEASED)' \
			-var 'agent_version=$(CURRENT_AGENT_VERSION_LINUX)' \
			-var 'ami_public=$(AMI_PUBLIC)' \
			-var 'ami_users=$(AMI_USERS_LIST)' \
			-var 'base_ami_id=$(if $(BASE_AMI_ID),$(BASE_AMI_ID),$(BASE_AMI_ID_UBUNTU2404_ARM64))' \
			buildkite-ami.pkr.hcl | tee $@

# -----------------------------------------
# Base AMI creation

# Build base AMI for linux amd64
packer-base-linux-amd64.output: $(PACKER_LINUX_BASE_FILES)
	docker run \
		-e AWS_DEFAULT_REGION  \
		-e AWS_PROFILE \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e PACKER_LOG \
		-v ${HOME}/.aws:/root/.aws \
		-v "$(PWD):/src" \
		--rm \
		-w /src/packer/linux/base \
		hashicorp/packer:full-$(PACKER_VERSION) build -timestamp-ui \
			-var 'region=$(AWS_REGION)' \
			-var 'arch=x86_64' \
			-var 'instance_type=$(AMD64_INSTANCE_TYPE)' \
			-var 'build_number=$(BUILDKITE_BUILD_NUMBER)' \
			-var 'is_released=$(IS_RELEASED)' \
			-var 'ami_public=$(AMI_PUBLIC)' \
			-var 'ami_users=$(AMI_USERS_LIST)' \
			base.pkr.hcl | tee $@

# CIS-hardened source AMI IDs (us-east-1 only)
# Unlike the standard AL2023 base, which uses a dynamic Packer amazon-ami data
# source lookup that works in any region, CIS AMIs are referenced by ID because
# they come from the CIS Marketplace publisher (owner 679593333241). AMI IDs are
# region-specific, so these only work in us-east-1 where our CI runs. To support
# other regions, replace these with a Packer data source filtering by owner and
# name pattern (requires an active Marketplace subscription in that region).
CIS_SOURCE_AMI_AMD64 ?= ami-0ade66ab1b3aaa37a
CIS_SOURCE_AMI_ARM64 ?= ami-039ef18047739861b

# Build base AMI for linux amd64 (CIS-hardened)
packer-base-linux-amd64-cis.output: $(PACKER_LINUX_BASE_FILES)
	docker run \
		-e AWS_DEFAULT_REGION  \
		-e AWS_PROFILE \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e PACKER_LOG \
		-v ${HOME}/.aws:/root/.aws \
		-v "$(PWD):/src" \
		--rm \
		-w /src/packer/linux/base \
		hashicorp/packer:full-$(PACKER_VERSION) build -timestamp-ui \
			-var 'region=$(AWS_REGION)' \
			-var 'arch=x86_64' \
			-var 'instance_type=$(AMD64_INSTANCE_TYPE)' \
			-var 'build_number=$(BUILDKITE_BUILD_NUMBER)' \
			-var 'is_released=$(IS_RELEASED)' \
			-var 'ami_public=$(AMI_PUBLIC)' \
			-var 'ami_users=$(AMI_USERS_LIST)' \
			-var 'cis_source_ami=$(CIS_SOURCE_AMI_AMD64)' \
			base.pkr.hcl | tee $@

# Build base AMI for linux arm64
packer-base-linux-arm64.output: $(PACKER_LINUX_BASE_FILES)
	docker run \
		-e AWS_DEFAULT_REGION  \
		-e AWS_PROFILE \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e PACKER_LOG \
		-v ${HOME}/.aws:/root/.aws \
		-v "$(PWD):/src" \
		--rm \
		-w /src/packer/linux/base \
		hashicorp/packer:full-$(PACKER_VERSION) build -timestamp-ui \
			-var 'region=$(AWS_REGION)' \
			-var 'arch=arm64' \
			-var 'instance_type=$(ARM64_INSTANCE_TYPE)' \
			-var 'build_number=$(BUILDKITE_BUILD_NUMBER)' \
			-var 'is_released=$(IS_RELEASED)' \
			-var 'ami_public=$(AMI_PUBLIC)' \
			-var 'ami_users=$(AMI_USERS_LIST)' \
			base.pkr.hcl | tee $@

# Build base AMI for ubuntu2404 amd64 (reuses packer/linux/base via os_distro)
packer-base-ubuntu2404-amd64.output: $(PACKER_LINUX_BASE_FILES)
	docker run \
		-e AWS_DEFAULT_REGION  \
		-e AWS_PROFILE \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e PACKER_LOG \
		-v ${HOME}/.aws:/root/.aws \
		-v "$(PWD):/src" \
		--rm \
		-w /src/packer/linux/base \
		hashicorp/packer:full-$(PACKER_VERSION) build -timestamp-ui \
			-var 'region=$(AWS_REGION)' \
			-var 'arch=x86_64' \
			-var 'os_distro=ubuntu2404' \
			-var 'instance_type=$(AMD64_INSTANCE_TYPE)' \
			-var 'build_number=$(BUILDKITE_BUILD_NUMBER)' \
			-var 'is_released=$(IS_RELEASED)' \
			-var 'ami_public=$(AMI_PUBLIC)' \
			-var 'ami_users=$(AMI_USERS_LIST)' \
			base.pkr.hcl | tee $@

# Build base AMI for ubuntu2404 arm64 (reuses packer/linux/base via os_distro)
packer-base-ubuntu2404-arm64.output: $(PACKER_LINUX_BASE_FILES)
	docker run \
		-e AWS_DEFAULT_REGION  \
		-e AWS_PROFILE \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e PACKER_LOG \
		-v ${HOME}/.aws:/root/.aws \
		-v "$(PWD):/src" \
		--rm \
		-w /src/packer/linux/base \
		hashicorp/packer:full-$(PACKER_VERSION) build -timestamp-ui \
			-var 'region=$(AWS_REGION)' \
			-var 'arch=arm64' \
			-var 'os_distro=ubuntu2404' \
			-var 'instance_type=$(ARM64_INSTANCE_TYPE)' \
			-var 'build_number=$(BUILDKITE_BUILD_NUMBER)' \
			-var 'is_released=$(IS_RELEASED)' \
			-var 'ami_public=$(AMI_PUBLIC)' \
			-var 'ami_users=$(AMI_USERS_LIST)' \
			base.pkr.hcl | tee $@

# -----------------------------------------
# fixperms

build/fix-perms-linux-amd64: $(FIXPERMS_FILES)
	docker run \
		-e CGO_ENABLED=0 \
		-e GOOS=linux \
		-e GOARCH=amd64 \
		-v "$(PWD):/src" \
		-w /src \
		--rm \
		golang:$(GO_VERSION) \
			go build -v -buildvcs=false -o "build/fix-perms-linux-amd64" ./internal/fixperms

build/fix-perms-linux-arm64: $(FIXPERMS_FILES)
	docker run \
		-e CGO_ENABLED=0 \
		-e GOOS=linux \
		-e GOARCH=arm64 \
		-v "$(PWD):/src" \
		-w /src \
		--rm \
		golang:$(GO_VERSION) \
			go build -v -buildvcs=false -o "build/fix-perms-linux-arm64" ./internal/fixperms

# Build goss in the golang container so no Go toolchain ends up in the AMI.
# Same flags as goss's release-build.sh. Rebuilds when the pin changes.
build/goss-linux-amd64: $(GOSS_VERSIONS_FILE)
	mkdir -p build
	docker run \
		-e CGO_ENABLED=0 \
		-e GOOS=linux \
		-e GOARCH=amd64 \
		-v "$(PWD)/build:/out" \
		--rm \
		golang:$(GO_VERSION) \
			bash -c 'set -euo pipefail; \
				git clone --quiet https://github.com/goss-org/goss /goss; \
				git -C /goss checkout --quiet $(GOSS_COMMIT); \
				cd /goss; \
				go build -trimpath -ldflags "-X github.com/goss-org/goss/util.Version=$(GOSS_VERSION) -s -w" -o /out/goss-linux-amd64 ./cmd/goss'

build/goss-linux-arm64: $(GOSS_VERSIONS_FILE)
	mkdir -p build
	docker run \
		-e CGO_ENABLED=0 \
		-e GOOS=linux \
		-e GOARCH=arm64 \
		-v "$(PWD)/build:/out" \
		--rm \
		golang:$(GO_VERSION) \
			bash -c 'set -euo pipefail; \
				git clone --quiet https://github.com/goss-org/goss /goss; \
				git -C /goss checkout --quiet $(GOSS_COMMIT); \
				cd /goss; \
				go build -trimpath -ldflags "-X github.com/goss-org/goss/util.Version=$(GOSS_VERSION) -s -w" -o /out/goss-linux-arm64 ./cmd/goss'
