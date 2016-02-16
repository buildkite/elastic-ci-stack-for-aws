
.PHONY: all clean build build-ami upload create-stack

all: build

build: build/aws-stack.json

build/aws-stack.json: templates/buildkite-elastic.yml templates/mappings.yml
	-mkdir -p build/
	cfoo $^ > $@

setup:
	gem install bundler --no-ri --no-rdoc
	bundle install

clean:
	-rm build/*

build-ami:
	cd packer/; packer build buildkite-ubuntu-15.04.json

upload: build/aws-stack.json
	aws s3 sync --acl public-read build s3://buildkite-aws-stack/

create-stack: build/aws-stack.json
	aws cloudformation create-stack \
	--output text \
	--stack-name bk-aws-stack-$(shell date +%Y-%m-%d-%H-%M) \
	--disable-rollback \
	--template-body "file://${PWD}/build/aws-stack.json" \
	--capabilities CAPABILITY_IAM \
	--parameters '$(shell cat config.json)'
