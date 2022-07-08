module github.com/onflow/flow-core-contracts/lib/go/test

go 1.16

require (
	github.com/onflow/cadence v0.21.3-0.20220511225809-808fe14141df
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.11.2-0.20220422202806-92ad02a996cc
	github.com/onflow/flow-core-contracts/lib/go/templates v0.11.2-0.20220422202806-92ad02a996cc
	github.com/onflow/flow-emulator v0.31.2-0.20220513151845-ef7513cb1cd0
	github.com/onflow/flow-ft/lib/go/templates v0.2.0
	github.com/onflow/flow-go-sdk v0.24.1-0.20220512181452-dec47e8451bb
	github.com/onflow/flow-go/crypto v0.24.3
	github.com/stretchr/testify v1.7.1-0.20210824115523-ab6dc3262822
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
