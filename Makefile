
all: build/cloudformation.json

clean:
	-rm build/cloudformation.json

build/cloudformation.json: buildkite-elastic.yml mappings.yml
	-mkdir -p build/
	cfoo $^ > $@
