module github.com/onflow/flow-core-contracts/lib/go/test

go 1.13

require (
	github.com/onflow/cadence v0.20.3
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.8.1-0.20220118003757-62d8157aac94
	github.com/onflow/flow-core-contracts/lib/go/templates v0.7.9
	github.com/onflow/flow-emulator v0.23.1-0.20210920151500-1778062338e5
	github.com/onflow/flow-ft/lib/go/templates v0.2.0
	github.com/onflow/flow-go v0.23.2-0.20220118213228-936a5a5a833d
	github.com/onflow/flow-go-sdk v0.24.0
	github.com/onflow/flow-go/crypto v0.23.3
	github.com/stretchr/testify v1.7.0
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
