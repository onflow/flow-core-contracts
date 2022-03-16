module github.com/onflow/flow-core-contracts/lib/go/test

go 1.16

require (
	github.com/onflow/cadence v0.21.3-0.20220310201609-481cb23a7d6b
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.10.2-0.20220316181225-1ae94da816da
	github.com/onflow/flow-core-contracts/lib/go/templates v0.10.1
	github.com/onflow/flow-emulator v0.28.2-0.20220316190436-48eed5bc3eb2
	github.com/onflow/flow-ft/lib/go/templates v0.2.0
	github.com/onflow/flow-go v0.25.1-0.20220316182245-76c3643c084a
	github.com/onflow/flow-go-sdk v0.24.0
	github.com/onflow/flow-go/crypto v0.24.3
	github.com/stretchr/testify v1.7.1-0.20210824115523-ab6dc3262822
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
