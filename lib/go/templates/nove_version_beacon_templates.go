package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// Admin Transactions
	changeVersionTableFilename = "nodeVersionBeacon/admin/change_version_table.cdc"

	// Scripts

	getVersionUpdateBufferScriptFilename = "nodeVersionBeacon/scripts/get_version_update_buffer.cdc"
)

// Admin Templates -------------------------------------------------------

// GenerateChangeVersionTableScript
func GenerateChangeVersionTableScript(env Environment) []byte {
	code := assets.MustAssetString(changeVersionTableFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetVersionUpdateBufferScript(env Environment) []byte {
	code := assets.MustAssetString(getVersionUpdateBufferScriptFilename)

	return []byte(ReplaceAddresses(code, env))
}
