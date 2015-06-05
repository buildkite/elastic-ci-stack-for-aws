
all: cloudformation.json

cloudformation.json: buildkite-elastic.yml mappings.yml
	cfoo $^ > $@
