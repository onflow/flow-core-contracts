.PHONY: test
test: 
	$(MAKE) generate -C lib/go
	$(MAKE) test -C lib/go
	$(MAKE) test -C lib/js/test
	$(MAKE) flow test --cover --covercode="contracts" tests/test_*.cdc

.PHONY: ci
ci:
	$(MAKE) ci -C lib/go
	$(MAKE) ci -C lib/js/test
	$(MAKE) flow test --cover --covercode="contracts" tests/test_*.cdc
