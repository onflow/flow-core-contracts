module github.com/onflow/lib/go/flow-core-contracts

go 1.14

require (
	github.com/axw/gocov v1.0.0 // indirect
	github.com/dapperlabs/flow-emulator v0.10.0
	github.com/davidlazar/go-crypto v0.0.0-20190912175916-7055855a373f // indirect
	github.com/dgraph-io/badger/v2 v2.0.3 // indirect
	github.com/gammazero/deque v0.0.0-20200310222745-50fa758af896 // indirect
	github.com/libp2p/go-libp2p-quic-transport v0.5.0 // indirect
	github.com/libp2p/go-sockaddr v0.1.0 // indirect
	github.com/onflow/cadence v0.8.0
	github.com/onflow/flow-core-contracts/lib/go/contracts v0.0.0-00010101000000-000000000000
	github.com/onflow/flow-core-contracts/lib/go/templates v0.0.0-00010101000000-000000000000
	github.com/onflow/flow-go-sdk v0.9.0
	github.com/rs/zerolog v1.19.0 // indirect
	github.com/stretchr/objx v0.2.0 // indirect
	github.com/stretchr/testify v1.6.1
)

replace github.com/onflow/flow-core-contracts/lib/go/contracts => ../contracts

replace github.com/onflow/flow-core-contracts/lib/go/templates => ../templates
