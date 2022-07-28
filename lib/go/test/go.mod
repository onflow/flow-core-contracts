module github.com/onflow/flow-core-contracts/lib/go/test

go 1.16

require (
	github.com/onflow/cadence v0.24.2-0.20220627202951-5a06fec82b4a
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.11.2-0.20220620142725-49b5accb2a84
	github.com/onflow/flow-core-contracts/lib/go/templates v0.11.2-0.20220513155751-c4c1f8d59f83
	github.com/onflow/flow-emulator v0.33.4
	github.com/onflow/flow-ft/lib/go/templates v0.2.0
	github.com/onflow/flow-go-sdk v0.26.5-0.20220629191626-900f9f91bffc
	github.com/onflow/flow-go/crypto v0.24.3
	github.com/stretchr/testify v1.7.5
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
