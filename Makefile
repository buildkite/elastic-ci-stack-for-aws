
all: cloudformation.json

cloudformation.json: templates/buildkite-elastic.yml
	cfoo $^ > $@