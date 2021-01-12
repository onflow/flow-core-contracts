package templates

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	inspectFieldFilename = "inspect_field.cdc"
	defaultField         = "transactionField"

	// FlowStorageFees templates

	changeStorageFeeParametersFilename = "/storageFees/admin/set_parameters.cdc"

	getStorageFeeConversionFilenane = "/storageFees/scripts/get_storage_fee_conversion.cdc"
	getStorageFeeMinimumFilename    = "/storageFees/scripts/get_storage_fee_min.cdc"
	getStorageCapacityFilename      = "/storageFees/scripts/get_storage_capacity.cdc"
)

// GenerateInspectFieldScript creates a script that reads
// a field from the smart contract and makes assertions
// about its value
func GenerateInspectFieldScript(field string) []byte {
	code := assets.MustAssetString(inspectFieldFilename)

	code = strings.ReplaceAll(
		code,
		defaultField,
		field,
	)

	return []byte(code)
}

// StorageFees Templates

func GenerateChangeStorageFeeParametersScript(env Environment) []byte {
	code := assets.MustAssetString(changeStorageFeeParametersFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetStorageFeeConversionScript(env Environment) []byte {
	code := assets.MustAssetString(getStorageFeeConversionFilenane)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetStorageFeeMinimumScript(env Environment) []byte {
	code := assets.MustAssetString(getStorageFeeMinimumFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetStorageCapacityScript(env Environment) []byte {
	code := assets.MustAssetString(getStorageCapacityFilename)

	return []byte(replaceAddresses(code, env))
}
