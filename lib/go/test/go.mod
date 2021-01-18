module github.com/onflow/lib/go/flow-core-contracts

go 1.14

require (
	github.com/onflow/cadence v0.10.5
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.6.1-0.20210113125452-03c054c55935
	github.com/onflow/flow-core-contracts/lib/go/templates v0.6.0
	github.com/onflow/flow-emulator v0.12.6-0.20210118152714-97ea438eed1a
	github.com/onflow/flow-ft/lib/go/templates v0.0.0-20201002112420-010719813062
	github.com/onflow/flow-go-sdk v0.12.3
	github.com/stretchr/testify v1.6.1
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
