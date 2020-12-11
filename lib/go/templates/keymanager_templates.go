package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const addKeyFilename = "keyManager/add_key.cdc"

// GenerateAddKeyScript generates a script that adds a key
// to an account using a KeyManager.
func GenerateAddKeyScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + addKeyFilename)

	return []byte(replaceAddresses(code, env))
}
