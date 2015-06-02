
all: cloudformation.json

cloudformation.json: buildkite-elastic.yml
	cfoo $^ > $@
