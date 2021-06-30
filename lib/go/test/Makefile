.PHONY: test
test: crypto_deps
	go test ./... --tags relic

.PHONY: crypto_deps
crypto_deps:
	bash build_crypto_dependency.sh

.PHONY: generate
generate:
	go generate

.PHONY: check-tidy
check-tidy: generate
	go mod tidy
	git diff --exit-code

.PHONY: ci
ci: check-tidy test
