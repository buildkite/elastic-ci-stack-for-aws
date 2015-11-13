
all: build/cloudformation.json

clean:
	-rm cloudformation.json

build/cloudformation.json: buildkite-elastic.yml mappings.yml
	-mkdir -p build/
	cfoo $^ > $@
