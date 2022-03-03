module github.com/onflow/flow-core-contracts/lib/go/test

go 1.13

require (
	github.com/onflow/cadence v0.23.0
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.10.2-0.20220303212430-bb14f05cef94
	github.com/onflow/flow-core-contracts/lib/go/templates v0.10.1
	github.com/onflow/flow-emulator v0.28.3-0.20220303215013-8a4f9d6ce02b
	github.com/onflow/flow-ft/lib/go/templates v0.2.0
	github.com/onflow/flow-go v0.23.2-0.20220303214230-b534557ab3f5
	github.com/onflow/flow-go-sdk v0.24.0
	github.com/onflow/flow-go/crypto v0.24.3-0.20220203151650-a18137528dd0
	github.com/stretchr/testify v1.7.1-0.20210824115523-ab6dc3262822
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
