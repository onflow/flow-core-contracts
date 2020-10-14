.PHONY: test
test:
	go test ./...

.PHONY: generate
generate:
	go generate

.PHONY: check-generated
check-generated:
	git diff -- lib/go/contracts/ --exit-code

.PHONY: ci
ci: generate check-generated test
