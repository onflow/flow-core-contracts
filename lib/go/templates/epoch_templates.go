package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// Admin Transactions
	deployQCandDKGFilename           = "epoch/admin/deploy_qc_dkg.cdc"
	deployEpochFilename              = "epoch/admin/deploy_epoch.cdc"
	updateEpochViewsFilename         = "epoch/admin/update_epoch_views.cdc"
	updateStakingViewsFilename       = "epoch/admin/update_staking_views.cdc"
	updateDKGViewsFilename           = "epoch/admin/update_dkg_phase_views.cdc"
	updateEpochConfigFilename        = "epoch/admin/update_epoch_config.cdc"
	updateNumClustersFilename        = "epoch/admin/update_clusters.cdc"
	updateRewardPercentageFilename   = "epoch/admin/update_reward.cdc"
	advanceViewFilename              = "epoch/admin/advance_view.cdc"
	resetEpochFilename               = "epoch/admin/reset_epoch.cdc"
	epochCalculateSetRewardsFilename = "epoch/admin/calculate_rewards.cdc"
	epochPayRewardsFilename          = "epoch/admin/pay_rewards.cdc"
	epochSetAutoRewardsFilename      = "epoch/admin/set_automatic_rewards.cdc"

	// Node Transactions
	epochRegisterNodeFilename           = "epoch/node/register_node.cdc"
	epochRegisterQCVoterFilename        = "epoch/node/register_qc_voter.cdc"
	epochRegisterDKGParticipantFilename = "epoch/node/register_dkg_participant.cdc"

	// Scripts
	getCurrentEpochCounterFilename  = "epoch/scripts/get_epoch_counter.cdc"
	getProposedEpochCounterFilename = "epoch/scripts/get_proposed_counter.cdc"
	getEpochMetadataFilename        = "epoch/scripts/get_epoch_metadata.cdc"
	getConfigMetadataFilename       = "epoch/scripts/get_config_metadata.cdc"
	getEpochPhaseFilename           = "epoch/scripts/get_epoch_phase.cdc"
	getCurrentViewFilename          = "epoch/scripts/get_current_view.cdc"
	getFlowTotalSupplyFilename      = "flowToken/scripts/get_supply.cdc"

	// test scripts
	getRandomizeFilename      = "epoch/scripts/get_randomize.cdc"
	getCreateClustersFilename = "epoch/scripts/get_create_clusters.cdc"
)

// Admin Templates -------------------------------------------------------

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

func GenerateUpdateEpochViewsScript(env Environment) []byte {
	code := assets.MustAssetString(updateEpochViewsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateUpdateStakingViewsScript(env Environment) []byte {
	code := assets.MustAssetString(updateStakingViewsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateUpdateDKGViewsScript(env Environment) []byte {
	code := assets.MustAssetString(updateDKGViewsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateUpdateEpochConfigScript(env Environment) []byte {
	code := assets.MustAssetString(updateEpochConfigFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateUpdateNumClustersScript(env Environment) []byte {
	code := assets.MustAssetString(updateNumClustersFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateUpdateRewardPercentageScript(env Environment) []byte {
	code := assets.MustAssetString(updateRewardPercentageFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateAdvanceViewScript(env Environment) []byte {
	code := assets.MustAssetString(advanceViewFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateResetEpochScript(env Environment) []byte {
	code := assets.MustAssetString(resetEpochFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateEpochCalculateSetRewardsScript(env Environment) []byte {
	code := assets.MustAssetString(epochCalculateSetRewardsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateEpochPayRewardsScript(env Environment) []byte {
	code := assets.MustAssetString(epochPayRewardsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateEpochSetAutomaticRewardsScript(env Environment) []byte {
	code := assets.MustAssetString(epochSetAutoRewardsFilename)

	return []byte(replaceAddresses(code, env))
}

// Node Templates -----------------------------------------------

func GenerateEpochRegisterNodeScript(env Environment) []byte {
	code := assets.MustAssetString(epochRegisterNodeFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateEpochRegisterQCVoterScript(env Environment) []byte {
	code := assets.MustAssetString(epochRegisterQCVoterFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateEpochRegisterDKGParticipantScript(env Environment) []byte {
	code := assets.MustAssetString(epochRegisterDKGParticipantFilename)

	return []byte(replaceAddresses(code, env))
}

// Script Templates ------------------------------------------------------

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

func GenerateGetRandomizeScript(env Environment) []byte {
	code := assets.MustAssetString(getRandomizeFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetCreateClustersScript(env Environment) []byte {
	code := assets.MustAssetString(getCreateClustersFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetCurrentViewScript(env Environment) []byte {
	code := assets.MustAssetString(getCurrentViewFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetFlowTotalSupplyScript(env Environment) []byte {
	code := assets.MustAssetString(getFlowTotalSupplyFilename)

	return []byte(replaceAddresses(code, env))
}
