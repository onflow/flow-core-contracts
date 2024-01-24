module github.com/onflow/flow-core-contracts/lib/go/templates

go 1.18

require (
	github.com/kevinburke/go-bindata v3.24.0+incompatible
	github.com/onflow/cadence v1.0.0-M3
	github.com/onflow/flow-go-sdk v0.44.1-0.20240124213231-78d9f08eeae1
	github.com/psiemens/sconfig v0.1.0
	github.com/spf13/cobra v1.5.0
)

require (
	github.com/BurntSushi/toml v1.3.2 // indirect
	github.com/SaveTheRbtz/mph v0.1.1-0.20240117162131-4166ec7869bc // indirect
	github.com/bits-and-blooms/bitset v1.7.0 // indirect
	github.com/btcsuite/btcd/btcec/v2 v2.2.1 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/decred/dcrd/dcrec/secp256k1/v4 v4.2.0 // indirect
	github.com/ethereum/go-ethereum v1.13.5 // indirect
	github.com/fsnotify/fsnotify v1.6.0 // indirect
	github.com/fxamacker/cbor/v2 v2.4.1-0.20230228173756-c0c9f774e40c // indirect
	github.com/fxamacker/circlehash v0.3.0 // indirect
	github.com/google/go-cmp v0.6.0 // indirect
	github.com/hashicorp/hcl v1.0.0 // indirect
	github.com/holiman/uint256 v1.2.3 // indirect
	github.com/inconshreveable/mousetrap v1.0.0 // indirect
	github.com/k0kubun/pp v3.0.1+incompatible // indirect
	github.com/klauspost/cpuid/v2 v2.2.5 // indirect
	github.com/kr/pretty v0.3.1 // indirect
	github.com/kr/text v0.2.0 // indirect
	github.com/logrusorgru/aurora/v4 v4.0.0 // indirect
	github.com/magiconair/properties v1.8.0 // indirect
	github.com/mattn/go-colorable v0.1.13 // indirect
	github.com/mattn/go-isatty v0.0.19 // indirect
	github.com/mitchellh/mapstructure v1.4.1 // indirect
	github.com/onflow/atree v0.6.1-0.20230711151834-86040b30171f // indirect
	github.com/onflow/crypto v0.25.0 // indirect
	github.com/pelletier/go-toml v1.2.0 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	github.com/rivo/uniseg v0.4.4 // indirect
	github.com/rogpeppe/go-internal v1.9.0 // indirect
	github.com/spf13/afero v1.9.2 // indirect
	github.com/spf13/cast v1.3.0 // indirect
	github.com/spf13/jwalterweatherman v1.0.0 // indirect
	github.com/spf13/pflag v1.0.5 // indirect
	github.com/spf13/viper v1.4.0 // indirect
	github.com/stretchr/testify v1.8.4 // indirect
	github.com/texttheater/golang-levenshtein/levenshtein v0.0.0-20200805054039-cae8b0eaed6c // indirect
	github.com/turbolent/prettier v0.0.0-20220320183459-661cc755135d // indirect
	github.com/x448/float16 v0.8.4 // indirect
	github.com/zeebo/blake3 v0.2.3 // indirect
	go.opentelemetry.io/otel v1.16.0 // indirect
	go.uber.org/goleak v1.2.1 // indirect
	golang.org/x/crypto v0.17.0 // indirect
	golang.org/x/exp v0.0.0-20240103183307-be819d1f06fc // indirect
	golang.org/x/sys v0.15.0 // indirect
	golang.org/x/text v0.14.0 // indirect
	golang.org/x/xerrors v0.0.0-20220907171357-04be3eba64a2 // indirect
	gonum.org/v1/gonum v0.13.0 // indirect
	gopkg.in/yaml.v2 v2.4.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)

// This retraction block retracts version v1.2.3, which was tagged out-of-order.
// Currently go considers v1.2.3 to be the latest version, due to semver ordering,
// despite it being several months old and many revisions behind the tip.
// This retract block is based on https://go.dev/ref/mod#go-mod-file-retract.
retract (
	v1.2.4 // contains retraction only
	v1.2.3 // accidentally published with out-of-order tag
)
