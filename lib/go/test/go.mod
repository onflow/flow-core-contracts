module github.com/onflow/lib/go/flow-core-contracts

go 1.14

require (
	github.com/axw/gocov v1.0.0 // indirect
	github.com/dapperlabs/flow-emulator v0.4.0
	github.com/gammazero/deque v0.0.0-20200310222745-50fa758af896 // indirect
	github.com/onflow/cadence v0.4.0
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.0.0-00010101000000-000000000000
	github.com/onflow/flow-core-contracts/lib/go/templates v0.0.0-00010101000000-000000000000
	github.com/onflow/flow-go-sdk v0.4.1
	github.com/onflow/flow/protobuf/go/flow v0.1.5-0.20200611205353-548107cc9aca // indirect
	github.com/stretchr/testify v1.5.1
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
