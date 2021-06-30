.PHONY: test
test:
	go test ./... --tags relic

.PHONY: generate
generate:
	go generate

.PHONY: check-tidy
check-tidy: generate
	go mod tidy
	git diff --exit-code

.PHONY: ci
ci: check-tidy test
