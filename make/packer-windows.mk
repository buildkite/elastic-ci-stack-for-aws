PACKER_WINDOWS_BASE_FILES = $(shell find packer/windows/base)
PACKER_WINDOWS_STACK_FILES = $(shell find packer/windows/stack)

BASE_AMI_ID_WINDOWS_AMD64 ?= $(call base_ami_from_output,packer-base-windows-amd64.output)

WIN64_INSTANCE_TYPE ?= m7i.xlarge

# NOTE: make removes the $ escapes, everything else is passed to the shell
CURRENT_AGENT_VERSION_WINDOWS ?= $(shell $(SED) -En 's/^\$$AGENT_VERSION = "(.+?)"$$/\1/p' packer/windows/stack/scripts/install-buildkite-agent.ps1)

# Build a windows mapping file for a single region and image id pair
mappings-for-windows-amd64-image: env-AWS_REGION env-IMAGE_ID
	mkdir -p build/
	printf "Mappings:\n  AWSRegion2AMI:\n    %s: { linuxamd64: '', linuxarm64: '', windows: %s, ubuntu2404amd64: '', ubuntu2404arm64: '' }\n" \
		"$(AWS_REGION)" $(IMAGE_ID) > build/mappings.yml

build/windows-amd64-ami.txt: packer-windows-amd64.output env-AWS_REGION
	mkdir -p build
	grep -Eo "$(AWS_REGION): (ami-.+)" $< | cut -d' ' -f2 | xargs echo -n > $@

# Build windows packer image
packer-windows-amd64.output: $(PACKER_WINDOWS_STACK_FILES) $(if $(strip $(BASE_AMI_ID)),,packer-base-windows-amd64.output)
	@echo Agent Version: $(CURRENT_AGENT_VERSION_WINDOWS)
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
		-w /src/packer/windows/stack \
		hashicorp/packer:full-$(PACKER_VERSION) build -timestamp-ui \
			-var 'region=$(AWS_REGION)' \
			-var 'arch=x86_64' \
			-var 'instance_type=$(WIN64_INSTANCE_TYPE)' \
			-var 'build_number=$(BUILDKITE_BUILD_NUMBER)' \
			-var 'is_released=$(IS_RELEASED)' \
			-var 'agent_version=$(CURRENT_AGENT_VERSION_WINDOWS)' \
			-var 'ami_public=$(AMI_PUBLIC)' \
			-var 'ami_users=$(AMI_USERS_LIST)' \
			-var 'base_ami_id=$(if $(BASE_AMI_ID),$(BASE_AMI_ID),$(BASE_AMI_ID_WINDOWS_AMD64))' \
			buildkite-ami.pkr.hcl | tee $@

# Build base AMI for windows amd64
packer-base-windows-amd64.output: $(PACKER_WINDOWS_BASE_FILES)
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
		-w /src/packer/windows/base \
		hashicorp/packer:full-$(PACKER_VERSION) build -timestamp-ui \
			-var 'region=$(AWS_REGION)' \
			-var 'arch=x86_64' \
			-var 'instance_type=$(WIN64_INSTANCE_TYPE)' \
			-var 'build_number=$(BUILDKITE_BUILD_NUMBER)' \
			-var 'is_released=$(IS_RELEASED)' \
			-var 'ami_public=$(AMI_PUBLIC)' \
			-var 'ami_users=$(AMI_USERS_LIST)' \
			base.pkr.hcl | tee $@
