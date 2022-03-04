module github.com/onflow/flow-core-contracts/lib/go/test

go 1.13

require (
	github.com/onflow/cadence v0.23.0
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.10.2-0.20220304185200-4994c7e4a19a
	github.com/onflow/flow-core-contracts/lib/go/templates v0.10.1
	github.com/onflow/flow-emulator v0.28.3-0.20220304192638-c8265ab42023
	github.com/onflow/flow-ft/lib/go/templates v0.2.0
	github.com/onflow/flow-go v0.23.2-0.20220304191851-2564b1124faa
	github.com/onflow/flow-go-sdk v0.24.0
	github.com/onflow/flow-go/crypto v0.24.3
	github.com/stretchr/testify v1.7.1-0.20210824115523-ab6dc3262822
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
