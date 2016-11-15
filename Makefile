.PHONY: all clean build build-ami upload create-stack update-stack download-mappings toc

BUILDKITE_STACK_BUCKET ?= buildkite-aws-stack
BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
STACK_NAME ?= buildkite
SHELL=/bin/bash -o pipefail
TEMPLATES=templates/buildkite-elastic.yml templates/autoscale.yml templates/metrics.yml templates/vpc.yml
STACKFILE=build/aws-stack.yml

build: $(STACKFILE)

.DELETE_ON_ERROR:
$(STACKFILE): $(TEMPLATES) templates/mappings.yml
	-mkdir -p build/
	cat $^ | awk '/^(\s+|$$)/ || !seen[$$0]++' > $(STACKFILE)

clean:
	-rm -f build/*

templates/mappings.yml:
	$(error Either run `make build-ami` to build the ami, or `make download-mappings` to download the latest public mappings)

download-mappings:
	echo "Downloading templates/mappings.yml for branch $(BRANCH)"
	curl -Lf -o templates/mappings.yml https://s3.amazonaws.com/buildkite-aws-stack/$(BRANCH)/mappings.yml
	touch templates/mappings.yml

build-ami:
	cd packer/; packer build buildkite-ami.json | tee ../packer.output
	cp templates/mappings.yml.template templates/mappings.yml
	sed -i.bak "s/packer_image_id/$$(grep -Eo 'us-east-1: (ami-.+)' packer.output | cut -d' ' -f2)/" templates/mappings.yml

upload: $(STACKFILE)
	aws s3 sync --acl public-read build s3://$(BUILDKITE_STACK_BUCKET)/

config.json:
	test -s config.json || $(error Please create a config.json file)

extra_tags.json:
	echo "{}" > extra_tags.json

create-stack: config.json $(STACKFILE) extra_tags.json
	aws cloudformation create-stack \
	--output text \
	--stack-name $(STACK_NAME) \
	--disable-rollback \
	--template-body "file://$(PWD)/$(STACKFILE)" \
	--capabilities CAPABILITY_IAM \
	--parameters "$$(cat config.json)" \
	--tags "$$(cat extra_tags.json)"

validate: $(STACKFILE)
	aws cloudformation validate-template \
	--output table \
	--template-body "file://$(PWD)/$(STACKFILE)"

update-stack: config.json templates/mappings.yml $(STACKFILE)
	aws cloudformation update-stack \
	--output text \
	--stack-name $(STACK_NAME) \
	--template-body "file://$(PWD)/$(STACKFILE)" \
	--capabilities CAPABILITY_IAM \
	--parameters "$$(cat config.json)"

toc:
	docker run -it --rm -v "$$(pwd):/app" node:slim bash -c "npm install -g markdown-toc && cd /app && markdown-toc -i Readme.md"
