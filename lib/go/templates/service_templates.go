package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (

	// FlowToken Templates
	mintFlowFilename       = "flowToken/mint_tokens.cdc"
	getFlowBalanceFilename = "flowToken/scripts/get_balance.cdc"

	// FlowStorageFees templates

	changeStorageFeeParametersFilename                    = "storageFees/admin/set_parameters.cdc"
	getStorageFeeConversionFilenane                       = "storageFees/scripts/get_storage_fee_conversion.cdc"
	getAccountsCapacityForTransactionStorageCheckFilename = "storageFees/scripts/get_accounts_capacity_for_transaction_storage_check.cdc"

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
	getExecutionEffortWeighs  = "FlowServiceAccount/scripts/get_execution_effort_weights.cdc"
	setExecutionEffortWeighs  = "FlowServiceAccount/set_execution_effort_weights.cdc"
	getExecutionMemoryWeighs  = "FlowServiceAccount/scripts/get_execution_memory_weights.cdc"
	setExecutionMemoryWeighs  = "FlowServiceAccount/set_execution_memory_weights.cdc"
	getExecutionMemoryLimit   = "FlowServiceAccount/scripts/get_execution_memory_limit.cdc"
	setExecutionMemoryLimit   = "FlowServiceAccount/set_execution_memory_limit.cdc"

	verifyPayerBalanceForTxExecution = "FlowServiceAccount/scripts/verify_payer_balance_for_tx_execution.cdc"
)

// FlowToken Templates
func GenerateMintFlowScript(env Environment) []byte {
	code := assets.MustAssetString(mintFlowFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetFlowBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(getFlowBalanceFilename)

	return []byte(ReplaceAddresses(code, env))
}

// StorageFees Templates

func GenerateChangeStorageFeeParametersScript(env Environment) []byte {
	code := assets.MustAssetString(changeStorageFeeParametersFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetStorageFeeConversionScript(env Environment) []byte {
	code := assets.MustAssetString(getStorageFeeConversionFilenane)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetAccountAvailableBalanceFilenameScript(env Environment) []byte {
	code := assets.MustAssetString(getAccountAvailableBalanceFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetStorageFeeMinimumScript(env Environment) []byte {
	code := assets.MustAssetString(getStorageFeeMinimumFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetStorageCapacityScript(env Environment) []byte {
	code := assets.MustAssetString(getStorageCapacityFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetAccountsCapacityForTransactionStorageCheckScript(env Environment) []byte {
	code := assets.MustAssetString(getAccountsCapacityForTransactionStorageCheckFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetIsAccountCreationRestricted(env Environment) []byte {
	code := assets.MustAssetString(getIsAccountCreationRestricted)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetAccountCreators(env Environment) []byte {
	code := assets.MustAssetString(getAccountCreators)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateSetIsAccountCreationRestricted(env Environment) []byte {
	code := assets.MustAssetString(setIsAccountCreationRestricted)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetIsAccountCreator(env Environment) []byte {
	code := assets.MustAssetString(getIsAccountCreator)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateAddAccountCreator(env Environment) []byte {
	code := assets.MustAssetString(addAccountCreator)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateRemoveAccountCreator(env Environment) []byte {
	code := assets.MustAssetString(removeAccountCreator)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetFeesBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(getFeesBalanceFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateDepositFeesScript(env Environment) []byte {
	code := assets.MustAssetString(depositFeesFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetFeeParametersScript(env Environment) []byte {
	code := assets.MustAssetString(getFeeParametersFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateSetFeeParametersScript(env Environment) []byte {
	code := assets.MustAssetString(setFeeParametersFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateSetFeeSurgeFactorScript(env Environment) []byte {
	code := assets.MustAssetString(setFeeSurgeFactorFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateSetExecutionEffortWeights(env Environment) []byte {
	code := assets.MustAssetString(setExecutionEffortWeighs)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetExecutionEffortWeights(env Environment) []byte {
	code := assets.MustAssetString(getExecutionEffortWeighs)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateSetExecutionMemoryWeights(env Environment) []byte {
	code := assets.MustAssetString(setExecutionMemoryWeighs)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetExecutionMemoryWeights(env Environment) []byte {
	code := assets.MustAssetString(getExecutionMemoryWeighs)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateSetExecutionMemoryLimit(env Environment) []byte {
	code := assets.MustAssetString(setExecutionMemoryLimit)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetExecutionMemoryLimit(env Environment) []byte {
	code := assets.MustAssetString(getExecutionMemoryLimit)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateVerifyPayerBalanceForTxExecution(env Environment) []byte {
	code := assets.MustAssetString(verifyPayerBalanceForTxExecution)

	return []byte(ReplaceAddresses(code, env))
}
