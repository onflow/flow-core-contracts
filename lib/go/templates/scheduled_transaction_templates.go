package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// Admin Transactions
	executeTransactionFilename               = "transactionScheduler/admin/execute_transaction.cdc"
	executeTransactionWithCapabilityFilename = "transactionScheduler/admin/execute_transaction_with_capability.cdc"
	createExecutionAccountFilename           = "transactionScheduler/admin/create_execution_account.cdc"
	processTransactionFilename               = "transactionScheduler/admin/process_scheduled_transactions.cdc"

	// User Transactions
	scheduleTransactionFilename = "transactionScheduler/schedule_transaction.cdc"

	// Scripts
	getSlotAvailableEffortFilename = "transactionScheduler/scripts/get_slot_available_effort.cdc"
	getStatusFilename              = "transactionScheduler/scripts/get_status.cdc"
)

// Admin Transactions

func GenerateExecuteTransactionScript(env Environment) []byte {
	code := assets.MustAssetString(executeTransactionFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateSchedulerExecutorTransactionScript(env Environment) []byte {
	code := assets.MustAssetString(executeTransactionWithCapabilityFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateCreateExecutionAccountScript(env Environment) []byte {
	code := assets.MustAssetString(createExecutionAccountFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateProcessTransactionScript(env Environment) []byte {
	code := assets.MustAssetString(processTransactionFilename)

	return []byte(ReplaceAddresses(code, env))
}

// User Transactions

func GenerateScheduleTransactionScript(env Environment) []byte {
	code := assets.MustAssetString(scheduleTransactionFilename)

	return []byte(ReplaceAddresses(code, env))
}

// Scripts

func GenerateGetTransactionStatusScript(env Environment) []byte {
	code := assets.MustAssetString(getStatusFilename)

	return []byte(ReplaceAddresses(code, env))
}
