module github.com/onflow/lib/go/flow-core-contracts

go 1.14

require (
	github.com/onflow/cadence v0.10.4
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.5.1-0.20201215153249-47243bd6dfc9
	github.com/onflow/flow-core-contracts/lib/go/templates v0.0.0-00010101000000-000000000000
	github.com/onflow/flow-emulator v0.13.1-beta1.0.20210106205641-79b550b5141f
	github.com/onflow/flow-ft/lib/go/templates v0.0.0-20201002112420-010719813062
	github.com/onflow/flow-go v0.13.1-0.20210106202829-4c5647b83a80
	github.com/onflow/flow-go-sdk v0.12.2
	github.com/stretchr/testify v1.6.1
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
