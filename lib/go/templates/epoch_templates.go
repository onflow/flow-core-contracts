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
	updateEpochTimingConfigFilename  = "epoch/admin/update_epoch_timing_config.cdc"
	updateNumClustersFilename        = "epoch/admin/update_clusters.cdc"
	updateRewardPercentageFilename   = "epoch/admin/update_reward.cdc"
	advanceViewFilename              = "epoch/admin/advance_view.cdc"
	resetEpochFilename               = "epoch/admin/reset_epoch.cdc"
	recoverEpochFilename             = "epoch/admin/recover_epoch.cdc"
	epochCalculateSetRewardsFilename = "epoch/admin/calculate_rewards.cdc"
	epochPayRewardsFilename          = "epoch/admin/pay_rewards.cdc"
	epochSetAutoRewardsFilename      = "epoch/admin/set_automatic_rewards.cdc"
	setBonusTokensFilename           = "epoch/admin/set_bonus_tokens.cdc"

	// Node Transactions
	epochRegisterNodeFilename           = "epoch/node/register_node.cdc"
	epochRegisterQCVoterFilename        = "epoch/node/register_qc_voter.cdc"
	epochRegisterDKGParticipantFilename = "epoch/node/register_dkg_participant.cdc"

	// Scripts
	getCurrentEpochCounterFilename   = "epoch/scripts/get_epoch_counter.cdc"
	getProposedEpochCounterFilename  = "epoch/scripts/get_proposed_counter.cdc"
	getEpochMetadataFilename         = "epoch/scripts/get_epoch_metadata.cdc"
	getConfigMetadataFilename        = "epoch/scripts/get_config_metadata.cdc"
	getTimingConfigFilename          = "epoch/scripts/get_epoch_timing_config.cdc"
	getTargetEndTimeForEpochFilename = "epoch/scripts/get_target_end_time_for_epoch.cdc"
	getEpochPhaseFilename            = "epoch/scripts/get_epoch_phase.cdc"
	getCurrentViewFilename           = "epoch/scripts/get_current_view.cdc"
	getFlowTotalSupplyFilename       = "flowToken/scripts/get_supply.cdc"
	getFlowBonusTokensFilename       = "epoch/scripts/get_bonus_tokens.cdc"

	// test scripts
	getRandomizeFilename      = "epoch/scripts/get_randomize.cdc"
	getCreateClustersFilename = "epoch/scripts/get_create_clusters.cdc"
)

// Admin Templates -------------------------------------------------------

// GenerateDeployQCDKGScript
func GenerateDeployQCDKGScript(env Environment) []byte {
	code := assets.MustAssetString(deployQCandDKGFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateDeployEpochScript
func GenerateDeployEpochScript(env Environment) []byte {
	code := assets.MustAssetString(deployEpochFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateUpdateEpochViewsScript(env Environment) []byte {
	code := assets.MustAssetString(updateEpochViewsFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateUpdateStakingViewsScript(env Environment) []byte {
	code := assets.MustAssetString(updateStakingViewsFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateUpdateDKGViewsScript(env Environment) []byte {
	code := assets.MustAssetString(updateDKGViewsFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateUpdateEpochConfigScript(env Environment) []byte {
	code := assets.MustAssetString(updateEpochConfigFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateUpdateEpochTimingConfigScript(env Environment) []byte {
	code := assets.MustAssetString(updateEpochTimingConfigFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateUpdateNumClustersScript(env Environment) []byte {
	code := assets.MustAssetString(updateNumClustersFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateUpdateRewardPercentageScript(env Environment) []byte {
	code := assets.MustAssetString(updateRewardPercentageFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateAdvanceViewScript(env Environment) []byte {
	code := assets.MustAssetString(advanceViewFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateResetEpochScript(env Environment) []byte {
	code := assets.MustAssetString(resetEpochFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateRecoverEpochScript(env Environment) []byte {
	code := assets.MustAssetString(recoverEpochFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateEpochCalculateSetRewardsScript(env Environment) []byte {
	code := assets.MustAssetString(epochCalculateSetRewardsFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateEpochPayRewardsScript(env Environment) []byte {
	code := assets.MustAssetString(epochPayRewardsFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateEpochSetAutomaticRewardsScript(env Environment) []byte {
	code := assets.MustAssetString(epochSetAutoRewardsFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateEpochSetBonusTokensScript(env Environment) []byte {
	code := assets.MustAssetString(setBonusTokensFilename)

	return []byte(ReplaceAddresses(code, env))
}

// Node Templates -----------------------------------------------

func GenerateEpochRegisterNodeScript(env Environment) []byte {
	code := assets.MustAssetString(epochRegisterNodeFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateEpochRegisterQCVoterScript(env Environment) []byte {
	code := assets.MustAssetString(epochRegisterQCVoterFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateEpochRegisterDKGParticipantScript(env Environment) []byte {
	code := assets.MustAssetString(epochRegisterDKGParticipantFilename)

	return []byte(ReplaceAddresses(code, env))
}

// Script Templates ------------------------------------------------------

func GenerateGetCurrentEpochCounterScript(env Environment) []byte {
	code := assets.MustAssetString(getCurrentEpochCounterFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetProposedEpochCounterScript(env Environment) []byte {
	code := assets.MustAssetString(getProposedEpochCounterFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetEpochMetadataScript(env Environment) []byte {
	code := assets.MustAssetString(getEpochMetadataFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetEpochConfigMetadataScript(env Environment) []byte {
	code := assets.MustAssetString(getConfigMetadataFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetEpochTimingConfigScript(env Environment) []byte {
	code := assets.MustAssetString(getTimingConfigFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetTargetEndTimeForEpochScript(env Environment) []byte {
	code := assets.MustAssetString(getTargetEndTimeForEpochFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetEpochPhaseScript(env Environment) []byte {
	code := assets.MustAssetString(getEpochPhaseFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetRandomizeScript(env Environment) []byte {
	code := assets.MustAssetString(getRandomizeFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetCreateClustersScript(env Environment) []byte {
	code := assets.MustAssetString(getCreateClustersFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetCurrentViewScript(env Environment) []byte {
	code := assets.MustAssetString(getCurrentViewFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetFlowTotalSupplyScript(env Environment) []byte {
	code := assets.MustAssetString(getFlowTotalSupplyFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetBonusTokensScript(env Environment) []byte {
	code := assets.MustAssetString(getFlowBonusTokensFilename)

	return []byte(ReplaceAddresses(code, env))
}
