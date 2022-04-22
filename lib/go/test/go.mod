module github.com/onflow/flow-core-contracts/lib/go/test

go 1.16

require (
	github.com/onflow/cadence v0.21.3-0.20220419065337-d5202c162010
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.11.2-0.20220421202640-c5cc115fdcbc
	github.com/onflow/flow-core-contracts/lib/go/templates v0.11.2-0.20220421202640-c5cc115fdcbc
	github.com/onflow/flow-emulator v0.31.2-0.20220422152808-6c116a9d88b7
	github.com/onflow/flow-ft/lib/go/templates v0.2.0
	github.com/onflow/flow-go v0.25.13-0.20220422145107-5a9458db1f1d
	github.com/onflow/flow-go-sdk v0.24.1-0.20220421152843-9ce4d554036e
	github.com/onflow/flow-go/crypto v0.24.3
	github.com/stretchr/testify v1.7.1-0.20210824115523-ab6dc3262822
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
