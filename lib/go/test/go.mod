module github.com/onflow/lib/go/flow-core-contracts

go 1.13

require (
	github.com/onflow/cadence v0.15.1
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.7.2
	github.com/onflow/flow-core-contracts/lib/go/templates v0.0.0-00010101000000-000000000000
	github.com/onflow/flow-emulator v0.19.0
	github.com/onflow/flow-ft/lib/go/templates v0.2.0
	github.com/onflow/flow-go-sdk v0.19.0
	github.com/stretchr/testify v1.7.0
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
