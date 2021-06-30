.PHONY: crypto_deps
crypto_deps:
	bash lib/go/test/build_crypto_dependency.sh


.PHONY: test
test: crypto_deps
	$(MAKE) generate -C lib/go
	$(MAKE) test -C lib/go

.PHONY: ci
ci:
	$(MAKE) ci -C lib/go
