.PHONY: test
test: generate
	$(MAKE) test -C lib/go
	flow test --cover --covercode="contracts" tests/*.cdc

.PHONY: generate
generate:
	$(MAKE) generate -C lib/go

.PHONY: ci
ci:
	$(MAKE) ci -C lib/go
	flow test --cover --covercode="contracts" tests/*.cdc
