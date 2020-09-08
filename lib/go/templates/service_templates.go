package templates

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../../transactions/... -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../transactions/...

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	filePath             = "../../../transactions/"
	inspectFieldFilename = "inspect_field.cdc"
	defaultField         = "transactionField"

	defaultFTAddress        = "FUNGIBLETOKENADDRESS"
	defaultFlowTokenAddress = "FLOWTOKENADDRESS"
	defaultIDTableAddress   = "IDENTITYTABLEADDRESS"
)

// GenerateInspectFieldScript creates a script that reads
// a field from the smart contract and makes assertions
// about its value
func GenerateInspectFieldScript(field string) []byte {
	code := assets.MustAssetString(filePath + inspectFieldFilename)

	code = strings.ReplaceAll(
		code,
		defaultField,
		field,
	)

	return []byte(code)
}

// ReplaceAddresses replaces the import address
// and phase in scripts that return info about a specific node and phase
func ReplaceAddresses(code, ftAddr, flowTokenAddr, idTableAddr string) string {

	code = strings.ReplaceAll(
		code,
		"0x"+defaultFTAddress,
		"0x"+ftAddr,
	)

	code = strings.ReplaceAll(
		code,
		"0x"+defaultFlowTokenAddress,
		"0x"+flowTokenAddr,
	)

	code = strings.ReplaceAll(
		code,
		"0x"+defaultIDTableAddress,
		"0x"+idTableAddr,
	)

	return code
}
