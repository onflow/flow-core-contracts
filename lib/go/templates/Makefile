.PHONY: generate
generate:
	go generate

.PHONY: check-generated
check-generated:
	git diff -- lib/go/templates/ --exit-code

.PHONY: ci
ci: generate check-generated
