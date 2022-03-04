module github.com/onflow/flow-core-contracts/lib/go/test

go 1.13

require (
	github.com/onflow/cadence v0.23.0
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.10.2-0.20220303222312-6b9de4f3fea5
	github.com/onflow/flow-core-contracts/lib/go/templates v0.10.1
	github.com/onflow/flow-emulator v0.28.3-0.20220304145855-1476059b2816
	github.com/onflow/flow-ft/lib/go/templates v0.2.0
	github.com/onflow/flow-go v0.23.2-0.20220304145234-bf10d55c40fa
	github.com/onflow/flow-go-sdk v0.24.0
	github.com/onflow/flow-go/crypto v0.24.3
	github.com/stretchr/testify v1.7.1-0.20210824115523-ab6dc3262822
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
