package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (

	// FlowStorageFees templates

	changeStorageFeeParametersFilename = "storageFees/admin/set_parameters.cdc"

	getStorageFeeConversionFilenane = "storageFees/scripts/get_storage_fee_conversion.cdc"

	getStorageFeeMinimumFilename = "storageFees/scripts/get_storage_fee_min.cdc"
	getStorageCapacityFilename   = "storageFees/scripts/get_storage_capacity.cdc"

	// Freeze templates

	freezeAccountFilename   = "FlowServiceAccount/freeze/freeze_account.cdc"
	unfreezeAccountFilename = "FlowServiceAccount/freeze/unfreeze_account.cdc"
	getFreezeStatusFilename = "FlowServiceAccount/freeze/get_freeze_status.cdc"
)

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

// FlowFreeze Templates

func GenerateFreezeAccountScript(env Environment) []byte {
	code := assets.MustAssetString(freezeAccountFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateUnfreezeAccountScript(env Environment) []byte {
	code := assets.MustAssetString(unfreezeAccountFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetFreezeStatusScript(env Environment) []byte {
	code := assets.MustAssetString(getFreezeStatusFilename)

	return []byte(replaceAddresses(code, env))
}
