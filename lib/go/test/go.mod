module github.com/onflow/lib/go/flow-core-contracts

go 1.14

require (
	github.com/dapperlabs/flow-emulator v0.10.1-0.20200928173046-8ff6b7f0ac0f
	github.com/onflow/cadence v0.8.0
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.0.0-00010101000000-000000000000
	github.com/onflow/flow-core-contracts/lib/go/templates v0.0.0-00010101000000-000000000000
	github.com/onflow/flow-ft/lib/go/templates v0.0.0-20200903174622-f9406edc16ba
	github.com/onflow/flow-go-sdk v0.9.0
	github.com/stretchr/objx v0.2.0 // indirect
	github.com/stretchr/testify v1.6.1
	google.golang.org/protobuf v1.23.0 // indirect
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
