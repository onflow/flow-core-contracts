module github.com/onflow/flow-core-contracts/lib/go/test

go 1.16

require (
	github.com/onflow/cadence v0.28.0
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.11.2-0.20220720151516-797b149ceaaa
	github.com/onflow/flow-core-contracts/lib/go/templates v0.11.2-0.20220720151516-797b149ceaaa
	github.com/onflow/flow-emulator v0.38.1
	github.com/onflow/flow-ft/lib/go/templates v0.2.0
	github.com/onflow/flow-go-sdk v0.29.0
	github.com/onflow/flow-go/crypto v0.24.4
	github.com/stretchr/testify v1.8.0
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates