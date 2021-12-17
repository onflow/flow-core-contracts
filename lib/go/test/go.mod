module github.com/onflow/flow-core-contracts/lib/go/test

go 1.13

require (
	github.com/onflow/cadence v0.19.1
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.7.9
	github.com/onflow/flow-core-contracts/lib/go/templates v0.7.9
	github.com/onflow/flow-emulator v0.23.1-0.20210920151500-1778062338e5
	github.com/onflow/flow-ft/lib/go/templates v0.2.0
	github.com/onflow/flow-go v0.21.1-0.20210917140310-6b187613e108
	github.com/onflow/flow-go-sdk v0.21.0
	github.com/onflow/flow-go/crypto v0.23.3
	github.com/stretchr/testify v1.7.0
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
