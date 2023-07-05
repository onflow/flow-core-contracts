module github.com/onflow/flow-core-contracts/lib/go/contracts

go 1.18

require (
	github.com/kevinburke/go-bindata v3.23.0+incompatible
	github.com/onflow/flow-ft/lib/go/contracts v0.7.0
	github.com/stretchr/testify v1.8.0
)

require (
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/kr/pretty v0.3.0 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	gopkg.in/check.v1 v1.0.0-20201130134442-10cb98267c6c // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

replace github.com/onflow/flow-ft/lib/go/contracts => ../../../../../flow-ft/lib/go/contracts
