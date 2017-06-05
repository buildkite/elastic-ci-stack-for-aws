.PHONY: all clean build build-ami upload create-stack update-stack download-mappings toc

BUILDKITE_STACK_BUCKET ?= buildkite-aws-stack
BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
VERSION ?= $(shell git describe --tags --candidates=1)
STACK_NAME ?= buildkite
SHELL=/bin/bash -o pipefail
TEMPLATES=templates/description.yml \
  templates/buildkite-elastic.yml \
  templates/autoscale.yml \
  templates/vpc.yml \
  templates/metrics.yml \
  templates/outputs.yml

all: build

build: build/aws-stack.json

build/aws-stack.json: $(TEMPLATES)
	docker run --rm -w /app -v "$(PWD):/app" node:slim bash \
		-c "yarn install --non-interactive && npm start $(VERSION)"

clean:
	-rm -f build/*

config.json:
	cp config.json.example config.json

build-ami: config.json
	docker run  -e AWS_DEFAULT_REGION  -e AWS_ACCESS_KEY_ID \
		-e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN \
                -v ${HOME}/.aws:/root/.aws \
		--rm --workdir /src -v "$(PWD)/packer:/src" -w /src hashicorp/packer:light \
			build buildkite-ami.json | tee packer.output
	jq --arg ImageId $$(grep -Eo 'us-east-1: (ami-.+)' packer.output | cut -d' ' -f2) \
		'[ .[] | select(.ParameterKey != "ImageId") ] + [{ParameterKey: "ImageId", ParameterValue: $$ImageId}]' \
		config.json  > config.json.temp
	mv config.json.temp config.json

upload: build/aws-stack.json
	aws s3 sync --acl public-read build s3://$(BUILDKITE_STACK_BUCKET)/

extra_tags.json:
	echo "{}" > extra_tags.json

create-stack: config.json build/aws-stack.json extra_tags.json
	aws cloudformation create-stack \
	--output text \
	--stack-name $(STACK_NAME) \
	--disable-rollback \
	--template-body "file://$(PWD)/build/aws-stack.json" \
	--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
	--parameters "$$(cat config.json)" \
	--tags "$$(cat extra_tags.json)"

validate: build/aws-stack.json
	aws cloudformation validate-template \
	--output table \
	--template-body "file://$(PWD)/build/aws-stack.json"

update-stack: config.json templates/mappings.yml build/aws-stack.json
	aws cloudformation update-stack \
	--output text \
	--stack-name $(STACK_NAME) \
	--template-body "file://$(PWD)/build/aws-stack.json" \
	--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
	--parameters "$$(cat config.json)"

toc:
	docker run -it --rm -v "$(PWD):/app" node:slim bash \
		-c "npm install -g markdown-toc && cd /app && markdown-toc -i Readme.md"
