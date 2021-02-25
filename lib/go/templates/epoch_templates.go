package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	deployQCandDKGFilename = "epoch/admin/deploy_qc_dkg.cdc"
	deployEpochFilename    = "epoch/admin/deploy_epoch.cdc"

	// Scripts
	getCurrentEpochCounterFilename  = "epoch/scripts/get_epoch_counter.cdc"
	getProposedEpochCounterFilename = "epoch/scripts/get_proposed_counter.cdc"
	getEpochMetadataFilename        = "epoch/scripts/get_epoch_metadata.cdc"
	getConfigMetadataFilename       = "epoch/scripts/get_config_metadata.cdc"
	getEpochPhaseFilename           = "epoch/scripts/get_epoch_phase.cdc"
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

// Script Templates ----------------------------------------------------------

func GenerateGetCurrentEpochCounterScript(env Environment) []byte {
	code := assets.MustAssetString(getCurrentEpochCounterFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetProposedEpochCounterScript(env Environment) []byte {
	code := assets.MustAssetString(getProposedEpochCounterFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetEpochMetadataScript(env Environment) []byte {
	code := assets.MustAssetString(getEpochMetadataFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetEpochConfigMetadataScript(env Environment) []byte {
	code := assets.MustAssetString(getConfigMetadataFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetEpochPhaseScript(env Environment) []byte {
	code := assets.MustAssetString(getEpochPhaseFilename)

	return []byte(replaceAddresses(code, env))
}
