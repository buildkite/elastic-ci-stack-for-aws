.PHONY: all clean build build-ami upload create-stack update-stack config.json

BUILDKITE_STACK_BUCKET ?= buildkite-aws-stack

all: setup build

build: build/aws-stack.json

templates/mappings.yml:
	curl -Lf -o templates/mappings.yml https://s3.amazonaws.com/buildkite-aws-stack/mappings.yml
	touch templates/mappings.yml

build/aws-stack.json: $(wildcard templates/*.yml)
	-mkdir -p build/
	bundle exec cfoo $^ > $@

setup:
	bundle check || ((which bundle || gem install bundler --no-ri --no-rdoc) && bundle install --path vendor/bundle)

clean:
	-rm -f build/*
	-rm -f templates/mappings.yml

build-ami:
	cd packer/; packer build buildkite-ami.json

upload: build/aws-stack.json
	aws s3 sync --acl public-read build s3://${BUILDKITE_STACK_BUCKET}/

config.json:
	test -s config.json || { echo "Please create a config.json file"; exit 1; }

create-stack: config.json templates/mappings.yml build/aws-stack.json
	aws cloudformation create-stack \
	--output text \
	--stack-name buildkite \
	--disable-rollback \
	--template-body "file://${PWD}/build/aws-stack.json" \
	--capabilities CAPABILITY_IAM \
	--parameters '$(shell cat config.json)'

validate: build/aws-stack.json
	aws cloudformation validate-template \
	--output table \
	--template-body "file://${PWD}/build/aws-stack.json"

update-stack: config.json templates/mappings.yml build/aws-stack.json
	aws cloudformation update-stack \
	--output text \
	--stack-name buildkite \
	--template-body "file://${PWD}/build/aws-stack.json" \
	--capabilities CAPABILITY_IAM \
	--parameters '$(shell cat config.json)'
