
.PHONY: all clean build build-ami upload create-stack

all: build

build: build/aws-stack.json

templates/mappings.yml:
	aws s3 cp s3://buildkite-aws-stack/mappings.yml templates/mappings.yml

build/aws-stack.json: $(wildcard templates/*.yml)
	-mkdir -p build/
	bundle exec cfoo $^ > $@

setup:
	which bundle || gem install bundler --no-ri --no-rdoc
	bundle install --path vendor/bundle

clean:
	-rm build/*
	-rm templates/mappings.yml

build-ami:
	cd packer/; packer build buildkite-ami.json

upload: build/aws-stack.json
	aws s3 sync --acl public-read build s3://buildkite-aws-stack/

create-stack: templates/mappings.yml build/aws-stack.json
	aws cloudformation create-stack \
	--output text \
	--stack-name buildkite-$(shell date +%Y-%m-%d-%H-%M) \
	--disable-rollback \
	--template-body "file://${PWD}/build/aws-stack.json" \
	--capabilities CAPABILITY_IAM \
	--parameters '$(shell cat config.json)'

validate: build/aws-stack.json
	aws cloudformation validate-template \
	--output table \
	--template-body "file://${PWD}/build/aws-stack.json"

