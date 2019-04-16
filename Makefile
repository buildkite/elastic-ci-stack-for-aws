.PHONY: all clean build packer upload

VERSION = $(shell git describe --tags --candidates=1)
SHELL = /bin/bash -o pipefail

PACKER_LINUX_FILES = $(exec find packer/linux)
PACKER_WINDOWS_FILES = $(exec find packer/windows)

AWS_REGION ?= us-east-1
AMZN_LINUX2_AMI ?= $(shell aws ec2 describe-images --region $(AWS_REGION) --owners amazon --filters 'Name=name,Values=amzn2-ami-hvm-2.0.????????-x86_64-gp2' 'Name=state,Values=available' --output json | jq -r '.Images | sort_by(.CreationDate) | last(.[]).ImageId')

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
# Template creation

# Build a linux mapping file for a single region and image id pair
mappings-for-linux-image: env-AWS_REGION env-IMAGE_ID
	mkdir -p build/
	printf "Mappings:\n  AWSRegion2LinuxAMI:\n    %s: { AMI: %s }\n" \
		"$(AWS_REGION)" $(IMAGE_ID) > build/mappings-linux.yml

# Build a windows mapping file for a single region and image id pair
mappings-for-windows-image: env-AWS_REGION env-IMAGE_ID
	mkdir -p build/
	printf "Mappings:\n  AWSRegion2WindowsAMI:\n    %s: { AMI: %s }\n" \
		"$(AWS_REGION)" $(IMAGE_ID) > build/mappings-windows.yml

build: build/aws-stack.yml

# Takes the mappings files and copies them into a generate stack template
build/aws-stack.yml: templates/aws-stack.yml build/mappings-linux.yml build/mappings-windows.yml
	awk '{ \
		if ($$0 == "  AWSRegion2LinuxAMI: {}") { \
			system("grep -v Mappings: build/mappings-linux.yml") \
		} else if ($$0 == "  AWSRegion2WindowsAMI: {}") { \
			system("grep -v Mappings: build/mappings-windows.yml") \
		} else { \
			print \
		}\
	}' $< | sed "s/%v/$(VERSION)/" > $@

# -----------------------------------------
# AMI creation with Packer

build/mappings-linux.yml: packer-linux.output env-AWS_REGION
	echo mkdir -p build
	printf "Mappings:\n  AWSRegion2LinuxAMI:\n    %s: { AMI: %s }\n" \
		"$(AWS_REGION)" $$(grep -Eo "$(AWS_REGION): (ami-.+)" $< \
		| cut -d' ' -f2) > $@

# Build linux packer image
packer-linux.output: $(PACKER_LINUX_FILES)
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
		-w /src/packer/linux \
		hashicorp/packer:1.0.4 build -var 'ami=$(AMZN_LINUX2_AMI)' -var 'region=$(AWS_REGION)' \
			buildkite-ami.json | tee $@

build/mappings-windows.yml: packer-windows.output env-AWS_REGION
	echo mkdir -p build
	printf "Mappings:\n  AWSRegion2WindowsAMI:\n    %s: { AMI: %s }\n" \
		"$(AWS_REGION)" $$(grep -Eo "$(AWS_REGION): (ami-.+)" $< \
		| cut -d' ' -f2) > $@

# Build windows packer image
packer-windows.output: $(PACKER_WINDOWS_FILES)
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
		-w /src/packer/windows \
		hashicorp/packer:1.0.4 build -var 'region=$(AWS_REGION)' \
			buildkite-ami.json | tee $@

# -----------------------------------------
# Cloudformation helpers

TEMPLATE = aws-stack.yml

config.json:
	cp config.json.example config.json

create-stack: build/aws-stack.yml env-STACK_NAME
	aws cloudformation create-stack \
		--output text \
		--stack-name $(STACK_NAME) \
		--disable-rollback \
		--template-body "file://$(PWD)/build/aws-stack.yml" \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--parameters "$$(cat config.json)"

update-stack: build/aws-stack.yml env-STACK_NAME
	aws cloudformation update-stack \
		--output text \
		--stack-name $(STACK_NAME) \
		--template-body "file://$(PWD)/build/aws-stack.yml" \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--parameters "$$(cat config.json)"

# -----------------------------------------
# Other

validate: build/aws-stack.yml
	aws cloudformation validate-template \
		--output text \
		--template-body "file://$(PWD)/build/aws-stack.yml"

generate-toc:
	docker run -it --rm -v "$(PWD):/app" node:slim bash \
		-c "npm install -g markdown-toc && cd /app && markdown-toc -i README.md"
