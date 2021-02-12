package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	deployQCandDKGFilename = "epoch/admin/deploy_qc_dkg.cdc"
	deployEpochFilename    = "epoch/admin/deploy_epoch.cdc"
)

// Admin Templates -----------------------------------------------------------

// GenerateDeployQCDKGScript
func GenerateDeployQCDKGScript(env Environment) []byte {
	code := assets.MustAssetString(deployQCandDKGFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateDeployEpochScript
func GenerateDeployEpochScript(env Environment) []byte {
	code := assets.MustAssetString(deployEpochFilename)

	return []byte(replaceAddresses(code, env))
}
