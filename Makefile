CFOO=cfoo

cloudformation.json: templates/buildkite-elastic.yml
	cfoo $^ > $@