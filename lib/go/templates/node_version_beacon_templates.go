package templates

import (
	_ "embed"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// Admin Transactions
	setVersionBoundaryFilename        = "nodeVersionBeacon/admin/set_version_boundary.cdc"
	setProtocolStateVersionFilename   = "nodeVersionBeacon/admin/set_protocol_state_version.cdc"
	deleteVersionBoundaryFilename     = "nodeVersionBeacon/admin/delete_version_boundary.cdc"
	heartbeatFilename                 = "nodeVersionBeacon/admin/heartbeat.cdc"
	changeVersionFreezePeriodFilename = "nodeVersionBeacon/admin/change_version_freeze_period.cdc"

	// Scripts
	getCurrentNodeVersionFilename          = "nodeVersionBeacon/scripts/get_current_node_version.cdc"
	getCurrentNodeVersionAsStringFilename  = "nodeVersionBeacon/scripts/get_current_node_version_as_string.cdc"
	getNextTableUpdatedSequenceFilename    = "nodeVersionBeacon/scripts/get_next_version_update_sequence.cdc"
	getNextVersionBoundaryFilename         = "nodeVersionBeacon/scripts/get_next_version_boundary.cdc"
	getVersionBoundariesFilename           = "nodeVersionBeacon/scripts/get_version_boundaries.cdc"
	getVersionBoundaryFreezePeriodFilename = "nodeVersionBeacon/scripts/get_version_boundary_freeze_period.cdc"
)

func GenerateSetVersionBoundaryScript(env Environment) []byte {
	code := assets.MustAssetString(setVersionBoundaryFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateSetProtocolStateVersionScript(env Environment) []byte {
	code := assets.MustAssetString(setProtocolStateVersionFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateDeleteVersionBoundaryScript(env Environment) []byte {
	code := assets.MustAssetString(deleteVersionBoundaryFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateHeartbeatScript(env Environment) []byte {
	code := assets.MustAssetString(heartbeatFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateChangeVersionFreezePeriodScript(env Environment) []byte {
	code := assets.MustAssetString(changeVersionFreezePeriodFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetCurrentNodeVersionScript(env Environment) []byte {
	code := assets.MustAssetString(getCurrentNodeVersionFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetCurrentNodeVersionAsStringScript(env Environment) []byte {
	code := assets.MustAssetString(getCurrentNodeVersionAsStringFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetNextTableUpdatedSequenceScript(env Environment) []byte {
	code := assets.MustAssetString(getNextTableUpdatedSequenceFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetNextVersionBoundaryScript(env Environment) []byte {
	code := assets.MustAssetString(getNextVersionBoundaryFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetVersionBoundariesScript(env Environment) []byte {
	code := assets.MustAssetString(getVersionBoundariesFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetVersionBoundaryFreezePeriodScript(env Environment) []byte {
	code := assets.MustAssetString(getVersionBoundaryFreezePeriodFilename)

	return []byte(ReplaceAddresses(code, env))
}
