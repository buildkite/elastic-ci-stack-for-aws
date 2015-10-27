
all: cloudformation.json

clean:
	-rm cloudformation.json

cloudformation.json: buildkite-elastic.yml mappings.yml
	cfoo $^ > $@
