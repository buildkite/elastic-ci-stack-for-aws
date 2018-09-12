.PHONY: all clean build packer upload

S3_BUCKET = buildkite-aws-stack
S3_BUCKET_PREFIX = dev/$(shell git rev-parse --abbrev-ref HEAD)
S3_ACL = public-read
AWS_REGION = us-east-1

VERSION = $(shell git describe --tags --candidates=1)
SHELL = /bin/bash -o pipefail
PACKER_FILES = $(exec find packer/)
TEMPLATES = build/aws-stack.yml build/agent.yml build/metrics.yml build/vpc.yml

ifeq ($(AWS_REGION),us-east-1)
	S3_URL=https://s3.amazonaws.com/$(S3_BUCKET)/$(S3_BUCKET_PREFIX)
else
	S3_URL=https://s3-$(AWS_REGION).amazonaws.com/$(S3_BUCKET)/$(S3_BUCKET_PREFIX)
endif

# Build the packer AMI, create cloudformation templates and copy to s3
all: build

# Remove any built cloudformation templates and packer output
clean:
	-rm -f build/*
	-rm packer.output

# -----------------------------------------
# Template creation

# Build all the cloudformation templates
build: $(TEMPLATES)

build/aws-stack.yml: templates/aws-stack/template.yml build/mapping.yml
	sed -e '/AMI Mappings go here/r./build/mapping.yml' templates/aws-stack/template.yml > build/aws-stack.yml
	sed -i '' "3 s/%v/$(VERSION)/" build/aws-stack.yml
	sed -i '' "s,%S3_URL,$(S3_URL)," build/aws-stack.yml

build/%.yml: templates/%/template.yml
	cp $< $@
	sed -i '' "3 s/%v/$(VERSION)/" $@

# -----------------------------------------
# AMI creation with Packer

# Use packer to create an AMI
packer: packer.output

# Use packer to create an AMI and write the output to packer.output
packer.output: $(PACKER_FILES)
	docker run \
		-e AWS_DEFAULT_REGION  \
		-e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY \
		-e AWS_SESSION_TOKEN \
		-e PACKER_LOG \
		-v ${HOME}/.aws:/root/.aws \
		-v "$(PWD):/src" \
		--rm \
		-w /src/packer \
		hashicorp/packer:1.0.4 build buildkite-ami.json | tee packer.output

# Create a mapping.yml file for the ami produced by packer
build/mapping.yml: packer.output
	mkdir -p build/
	printf "Mappings:\n  AWSRegion2AMI:\n    %s: { AMI: %s }\n" \
		"$(AWS_REGION)" $$(grep -Eo "$(AWS_REGION): (ami-.+)" packer.output | cut -d' ' -f2) > build/mapping.yml

# -----------------------------------------
# Upload to S3

upload: $(TEMPLATES)
	aws s3 sync --acl "$(S3_ACL)" build/ s3://$(S3_BUCKET)/$(S3_BUCKET_PREFIX)/

# -----------------------------------------
# Cloudformation helpers

TEMPLATE = aws-stack.yml

config.json:
	cp config.json.example config.json

create-stack: build/aws-stack.yml
	aws cloudformation create-stack \
		--output text \
		--stack-name $(STACK_NAME) \
		--disable-rollback \
		--template-url "$(S3_URL)/$(TEMPLATE)" \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--parameters "$$(cat config.json)"

update-stack: build/aws-stack.yml
	aws cloudformation update-stack \
		--output text \
		--stack-name $(STACK_NAME) \
		--template-url "$(S3_URL)/$(TEMPLATE)" \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--parameters "$$(cat config.json)"

# -----------------------------------------
# Other

validate: $(TEMPLATES)
	aws cloudformation validate-template \
		--output table \
		--template-body "file://$(PWD)/build/vpc.yml"
	aws cloudformation validate-template \
		--output table \
		--template-body "file://$(PWD)/build/agent.yml"
	aws cloudformation validate-template \
		--output table \
		--template-body "file://$(PWD)/build/metrics.yml"
	aws cloudformation validate-template \
		--output table \
		--template-body "file://$(PWD)/build/aws-stack.yml"

generate-toc:
	docker run -it --rm -v "$(PWD):/app" node:slim bash \
		-c "npm install -g markdown-toc && cd /app && markdown-toc -i README.md"
