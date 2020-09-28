package templates

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../../transactions/... -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../transactions/...

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
	"github.com/onflow/flow-go-sdk"
)

const (
	filePath             = "../../../transactions/"
	inspectFieldFilename = "inspect_field.cdc"
	defaultField         = "transactionField"
	defaultServiceAddr   = "f8d6e0586b0a20c7"
)

// GenerateInspectFieldScript creates a script that reads
// a field from the smart contract and makes assertions
// about its value
func GenerateInspectFieldScript(field string, addr flow.Address) []byte {
	code := assets.MustAssetString(filePath + inspectFieldFilename)

	code = strings.ReplaceAll(
		code,
		defaultField,
		field,
	)

	code = strings.ReplaceAll(
		code,
		defaultServiceAddr,
		addr.Hex(),
	)

	return []byte(code)
}
