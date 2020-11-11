module github.com/onflow/lib/go/flow-core-contracts

go 1.14

require (
	github.com/dapperlabs/flow-emulator v0.10.1-0.20200928173046-8ff6b7f0ac0f
	github.com/onflow/cadence v0.10.1
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.1.0
	github.com/onflow/flow-core-contracts/lib/go/templates v0.0.0-00010101000000-000000000000
	github.com/onflow/flow-ft/lib/go/templates v0.0.0-20201002112420-010719813062
	github.com/onflow/flow-go-sdk v0.12.1
	github.com/onflow/flow/protobuf/go/flow v0.1.8 // indirect
	github.com/spf13/cobra v1.1.1 // indirect
	github.com/stretchr/testify v1.6.1
	google.golang.org/api v0.31.0 // indirect
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
