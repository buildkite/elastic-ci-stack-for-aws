.PHONY: all clean build build-ami upload create-stack update-stack download-mappings

# stable / unstable / experimental
AGENT_RELEASE_STREAM ?= stable
BUILDKITE_STACK_BUCKET ?= buildkite-aws-stack
BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
STACK_NAME =? buildkite
SHELL = /bin/bash -o pipefail

mappings_file = templates/mappings-${AGENT_RELEASE_STREAM}.yml

all: setup build

build: build/aws-stack.json

build/aws-stack.json: $(wildcard templates/*.yml) ${mappings_file}
	-mkdir -p build/
	bundle exec cfoo $^ > $@

setup:
	bundle check || ((which bundle || gem install bundler --no-ri --no-rdoc) && bundle install --path vendor/bundle)

clean:
	-rm -f build/*

${mappings_file}:
	$(error Either run `make build-ami` to build the ami, or `make download-mappings` to download the latest public mappings)

download-mappings:
	echo "Downloading ${mappings_file} for branch ${BRANCH}"
	curl -Lf -o ${mappings_file} https://s3.amazonaws.com/buildkite-aws-stack/${AGENT_RELEASE_STREAM}/${BUILDKITE_BRANCH}/mappings.yml
	touch ${mappings_file}

build-ami:
	cd packer/; packer build -var "agent_release_stream=${AGENT_RELEASE_STREAM}" buildkite-ami.json | tee ../packer.output
	cp templates/mappings.yml.template ${mappings_file}
	sed -i.bak "s/packer_image_id/$(shell grep -Eo 'us-east-1: (ami-.+)' packer.output | cut -d' ' -f2)/" ${mappings_file}

upload: build/aws-stack.json
	aws s3 sync --acl public-read build s3://${BUILDKITE_STACK_BUCKET}/

config.json:
	test -s config.json || $(error Please create a config.json file)

create-stack: config.json build/aws-stack.json
	aws cloudformation create-stack \
	--output text \
	--stack-name ${STACK_NAME} \
	--disable-rollback \
	--template-body "file://${PWD}/build/aws-stack.json" \
	--capabilities CAPABILITY_IAM \
	--parameters '$(shell cat config.json)'

validate: build/aws-stack.json
	aws cloudformation validate-template \
	--output table \
	--template-body "file://${PWD}/build/aws-stack.json"

update-stack: config.json ${mappings_file} build/aws-stack.json
	aws cloudformation update-stack \
	--output text \
	--stack-name ${STACK_NAME} \
	--template-body "file://${PWD}/build/aws-stack.json" \
	--capabilities CAPABILITY_IAM \
	--parameters '$(shell cat config.json)'
