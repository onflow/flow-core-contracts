package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (

	// FlowStorageFees templates

	changeStorageFeeParametersFilename = "storageFees/admin/set_parameters.cdc"

	getStorageFeeConversionFilenane = "storageFees/scripts/get_storage_fee_conversion.cdc"

	getAccountAvailableBalanceFilename = "storageFees/scripts/get_account_available_balance.cdc"
	getStorageFeeMinimumFilename       = "storageFees/scripts/get_storage_fee_min.cdc"
	getStorageCapacityFilename         = "storageFees/scripts/get_storage_capacity.cdc"

	getAccountCreators             = "FlowServiceAccount/scripts/get_account_creators.cdc"
	getIsAccountCreationRestricted = "FlowServiceAccount/scripts/get_is_account_creation_restricted.cdc"
	getIsAccountCreator            = "FlowServiceAccount/scripts/get_is_account_creator.cdc"
	setIsAccountCreationRestricted = "FlowServiceAccount/set_is_account_creation_restricted.cdc"
	addAccountCreator              = "FlowServiceAccount/add_account_creator.cdc"
	removeAccountCreator           = "FlowServiceAccount/remove_account_creator.cdc"

	depositFeesFilename       = "FlowServiceAccount/deposit_fees.cdc"
	getFeesBalanceFilename    = "FlowServiceAccount/scripts/get_fees_balance.cdc"
	getFeeParametersFilename  = "FlowServiceAccount/scripts/get_tx_fee_parameters.cdc"
	setFeeParametersFilename  = "FlowServiceAccount/set_tx_fee_parameters.cdc"
	setFeeSurgeFactorFilename = "FlowServiceAccount/set_tx_fee_surge_factor.cdc"
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

func GenerateGetAccountAvailableBalanceFilenameScript(env Environment) []byte {
	code := assets.MustAssetString(getAccountAvailableBalanceFilename)

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

func GenerateGetIsAccountCreationRestricted(env Environment) []byte {
	code := assets.MustAssetString(getIsAccountCreationRestricted)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetAccountCreators(env Environment) []byte {
	code := assets.MustAssetString(getAccountCreators)

	return []byte(replaceAddresses(code, env))
}

func GenerateSetIsAccountCreationRestricted(env Environment) []byte {
	code := assets.MustAssetString(setIsAccountCreationRestricted)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetIsAccountCreator(env Environment) []byte {
	code := assets.MustAssetString(getIsAccountCreator)

	return []byte(replaceAddresses(code, env))
}

func GenerateAddAccountCreator(env Environment) []byte {
	code := assets.MustAssetString(addAccountCreator)

	return []byte(replaceAddresses(code, env))
}

func GenerateRemoveAccountCreator(env Environment) []byte {
	code := assets.MustAssetString(removeAccountCreator)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetFeesBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(getFeesBalanceFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDepositFeesScript(env Environment) []byte {
	code := assets.MustAssetString(depositFeesFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetFeeParametersScript(env Environment) []byte {
	code := assets.MustAssetString(getFeeParametersFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateSetFeeParametersScript(env Environment) []byte {
	code := assets.MustAssetString(setFeeParametersFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateSetFeeSurgeFactorScript(env Environment) []byte {
	code := assets.MustAssetString(setFeeSurgeFactorFilename)

	return []byte(replaceAddresses(code, env))
}
