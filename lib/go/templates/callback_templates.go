package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// Admin Transactions
	executeCallbackFilename = "callbackScheduler/admin/execute_callback.cdc"
	processCallbackFilename = "callbackScheduler/admin/process_callback.cdc"

	// User Transactions
	scheduleCallbackFilename = "callbackScheduler/schedule_callback.cdc"

	// Scripts
	getSlotAvailableEffortFilename = "callbackScheduler/scripts/get_slot_available_effort.cdc"
	getStatusFilename              = "callbackScheduler/scripts/get_status.cdc"
)

// Admin Transactions

func GenerateExecuteCallbackScript(env Environment) []byte {
	code := assets.MustAssetString(executeCallbackFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateProcessCallbackScript(env Environment) []byte {
	code := assets.MustAssetString(processCallbackFilename)

	return []byte(ReplaceAddresses(code, env))
}

// User Transactions

func GenerateScheduleCallbackScript(env Environment) []byte {
	code := assets.MustAssetString(processCallbackFilename)

	return []byte(ReplaceAddresses(code, env))
}

// Scripts

func GenerateGetCallbackStatusScript(env Environment) []byte {
	code := assets.MustAssetString(getStatusFilename)

	return []byte(ReplaceAddresses(code, env))
}
