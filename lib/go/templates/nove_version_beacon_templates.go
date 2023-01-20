package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// Admin Transactions
	addVersionToTableFilename = "nodeVersionBeacon/admin/add_version_to_table.cdc"
	emitVersionTableFilename  = "nodeVersionBeacon/admin/emit_version_table.cdc"

	// Scripts

	getVersionUpdateBufferScriptFilename = "nodeVersionBeacon/scripts/get_version_update_buffer.cdc"
)

// Admin Templates -------------------------------------------------------

// GenerateAddVersionToTableScript
func GenerateAddVersionToTableScript(env Environment) []byte {
	code := assets.MustAssetString(addVersionToTableFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateEmitVersionTableScript(env Environment) []byte {
	code := assets.MustAssetString(emitVersionTableFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetVersionUpdateBufferScript(env Environment) []byte {
	code := assets.MustAssetString(getVersionUpdateBufferScriptFilename)

	return []byte(ReplaceAddresses(code, env))
}
