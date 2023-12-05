module github.com/onflow/flow-core-contracts/lib/go/contracts

go 1.18

require (
	github.com/kevinburke/go-bindata v3.23.0+incompatible
	github.com/onflow/flow-ft/lib/go/contracts v0.7.1-0.20230711213910-baad011d2b13
	github.com/onflow/flow-go-sdk v0.41.6
	github.com/onflow/flow-nft/lib/go/contracts v1.1.0
	github.com/stretchr/testify v1.8.2
)

require (
	github.com/bits-and-blooms/bitset v1.5.0 // indirect
	github.com/btcsuite/btcd/btcec/v2 v2.2.1 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/decred/dcrd/dcrec/secp256k1/v4 v4.0.1 // indirect
	github.com/ethereum/go-ethereum v1.9.13 // indirect
	github.com/fxamacker/cbor/v2 v2.4.1-0.20230228173756-c0c9f774e40c // indirect
	github.com/fxamacker/circlehash v0.3.0 // indirect
	github.com/go-test/deep v1.1.0 // indirect
	github.com/klauspost/cpuid/v2 v2.2.4 // indirect
	github.com/logrusorgru/aurora/v4 v4.0.0 // indirect
	github.com/onflow/atree v0.6.0 // indirect
	github.com/onflow/cadence v0.39.12 // indirect
	github.com/onflow/flow-go/crypto v0.24.7 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	github.com/rivo/uniseg v0.4.4 // indirect
	github.com/texttheater/golang-levenshtein/levenshtein v0.0.0-20200805054039-cae8b0eaed6c // indirect
	github.com/turbolent/prettier v0.0.0-20220320183459-661cc755135d // indirect
	github.com/x448/float16 v0.8.4 // indirect
	github.com/zeebo/blake3 v0.2.3 // indirect
	go.opentelemetry.io/otel v1.14.0 // indirect
	golang.org/x/crypto v0.7.0 // indirect
	golang.org/x/sys v0.6.0 // indirect
	golang.org/x/text v0.8.0 // indirect
	golang.org/x/xerrors v0.0.0-20220907171357-04be3eba64a2 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

// This retraction block retracts version v1.2.3, which was tagged out-of-order.
// Currently go considers v1.2.3 to be the latest version, due to semver ordering,
// despite it being several months old and many revisions behind the tip.
// This retract block is based on https://go.dev/ref/mod#go-mod-file-retract.
retract (
	v1.2.3 // accidentally published with out-of-order tag
	v1.2.4 // contains retraction only
)