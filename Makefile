
.PHONY: all clean build build-ami upload create-stack

all: build

build: build/aws-stack.json build/buildkite-lifecycle-agent

templates/mappings.yml:
	curl -Lf -o templates/mappings.yml https://s3.amazonaws.com/buildkite-aws-stack/mappings.yml

build/aws-stack.json: templates/buildkite-elastic.yml templates/mappings.yml templates/autoscale.yml templates/vpc.yml
	-mkdir -p build/
	cfoo $^ > $@

build/buildkite-lifecycle-agent: lifecycle/main.go
	-mkdir -p build/
	which glide || go get github.com/Masterminds/glide
	cd lifecycle/ && glide install && go build -o ../build/buildkite-lifecycle-agent main.go

clean:
	-rm build/*
	-rm templates/mappings.yml

build-ami:
	cd packer/; packer build buildkite-ami.json

upload-stack: build/aws-stack.json
	aws s3 sync --acl public-read build s3://buildkite-aws-stack/aws-stack.json

create-stack: build/aws-stack.json
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

