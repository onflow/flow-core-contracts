module github.com/onflow/flow-core-contracts/lib/go/test

go 1.16

require (
	github.com/onflow/cadence v0.21.3-0.20220317173919-b23d45bcd67d
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.11.1-0.20220324170006-d69b5668d9f3
	github.com/onflow/flow-core-contracts/lib/go/templates v0.11.1-0.20220324170006-d69b5668d9f3
	github.com/onflow/flow-emulator v0.30.1-0.20220324184604-cd80f00ccc2c
	github.com/onflow/flow-ft/lib/go/templates v0.2.0
	github.com/onflow/flow-go v0.25.3-0.20220324180634-4afe191a92a3
	github.com/onflow/flow-go-sdk v0.24.0
	github.com/onflow/flow-go/crypto v0.24.3
	github.com/stretchr/testify v1.7.1-0.20210824115523-ab6dc3262822
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
