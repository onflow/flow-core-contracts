package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	transferDeployFilename = "idTableStaking/admin/transfer_minter_deploy.cdc"

	removeNodeFilename              = "idTableStaking/admin/remove_node.cdc"
	endStakingFilename              = "idTableStaking/admin/end_staking.cdc"
	removeUnapprovedNodesFilename   = "idTableStaking/admin/remove_unapproved_nodes.cdc"
	setApprovedNodesFilename        = "idTableStaking/admin/set_approved_nodes.cdc"
	NEWsetApprovedNodesFilename     = "idTableStaking/admin/set_approved_nodes_new.cdc"
	addApprovedNodesFilename        = "idTableStaking/admin/add_approved_nodes.cdc"
	removeApprovedNodesFilename     = "idTableStaking/admin/remove_approved_nodes.cdc"
	payRewardsFilename              = "idTableStaking/admin/pay_rewards.cdc"
	moveTokensFilename              = "idTableStaking/admin/move_tokens.cdc"
	endEpochFilename                = "idTableStaking/admin/end_epoch.cdc"
	changeMinimumsFilename          = "idTableStaking/admin/change_minimums.cdc"
	changeCutFilename               = "idTableStaking/admin/change_cut.cdc"
	changePayoutFilename            = "idTableStaking/admin/change_payout.cdc"
	endEpochChangePayoutFilename    = "idTableStaking/admin/end_epoch_change_payout.cdc"
	startStakingFilename            = "idTableStaking/admin/start_staking.cdc"
	upgradeStakingFilename          = "idTableStaking/admin/upgrade_staking.cdc"
	setClaimedFilename              = "idTableStaking/admin/set_claimed.cdc"
	transferAdminCapabilityFilename = "idTableStaking/admin/transfer_admin.cdc"
	capabilityEndEpochFilename      = "idTableStaking/admin/capability_end_epoch.cdc"
	transferFeesAdminFilename       = "idTableStaking/admin/transfer_fees_admin.cdc"
	setNonOperationalFilename       = "idTableStaking/admin/set_non_operational.cdc"
	setCandidateLimitFilename       = "idTableStaking/admin/change_candidate_limit.cdc"

	// for testing only
	scaleRewardsTestFilename = "idTableStaking/admin/scale_rewards_test.cdc"

	registerNodeFilename            = "idTableStaking/node/register_node.cdc"
	stakeNewTokensFilename          = "idTableStaking/node/stake_new_tokens.cdc"
	stakeUnstakedTokensFilename     = "idTableStaking/node/stake_unstaked_tokens.cdc"
	stakeRewardedTokensFilename     = "idTableStaking/node/stake_rewarded_tokens.cdc"
	unstakeTokensFilename           = "idTableStaking/node/request_unstake.cdc"
	unstakeAllFilename              = "idTableStaking/node/unstake_all.cdc"
	withdrawUnstakedTokensFilename  = "idTableStaking/node/withdraw_unstaked_tokens.cdc"
	withdrawRewardedTokensFilename  = "idTableStaking/node/withdraw_rewarded_tokens.cdc"
	updateNetworkingAddressFilename = "idTableStaking/node/update_networking_address.cdc"
	addPublicNodeCapabilityFilename = "idTableStaking/node/node_add_capability.cdc"

	registerManyNodesFilename = "idTableStaking/node/register_many_nodes.cdc"

	getTableFilename                            = "idTableStaking/scripts/get_table.cdc"
	currentTableFilename                        = "idTableStaking/scripts/get_current_table.cdc"
	proposedTableFilename                       = "idTableStaking/scripts/get_proposed_table.cdc"
	getNodeInfoScript                           = "idTableStaking/scripts/get_node_info.cdc"
	getNodeInfoFromAddressScript                = "idTableStaking/scripts/get_node_info_from_address.cdc"
	getRoleFilename                             = "idTableStaking/scripts/get_node_role.cdc"
	getNetworkingAddrFilename                   = "idTableStaking/scripts/get_node_networking_addr.cdc"
	getNetworkingKeyFilename                    = "idTableStaking/scripts/get_node_networking_key.cdc"
	getStakingKeyFilename                       = "idTableStaking/scripts/get_node_staking_key.cdc"
	getInitialWeightFilename                    = "idTableStaking/scripts/get_node_initial_weight.cdc"
	stakedBalanceFilename                       = "idTableStaking/scripts/get_node_staked_tokens.cdc"
	comittedBalanceFilename                     = "idTableStaking/scripts/get_node_committed_tokens.cdc"
	unstakedBalanceFilename                     = "idTableStaking/scripts/get_node_unstaked_tokens.cdc"
	rewardBalanceFilename                       = "idTableStaking/scripts/get_node_rewarded_tokens.cdc"
	unstakingBalanceFilename                    = "idTableStaking/scripts/get_node_unstaking_tokens.cdc"
	getTotalCommitmentFilename                  = "idTableStaking/scripts/get_node_total_commitment.cdc"
	getTotalCommitmentWithoutDelegatorsFilename = "idTableStaking/scripts/get_node_total_commitment_without_delegators.cdc"
	getUnstakingRequestFilename                 = "idTableStaking/scripts/get_node_unstaking_request.cdc"
	getCutPercentageFilename                    = "idTableStaking/scripts/get_cut_percentage.cdc"
	getNonOperationalListFilename               = "idTableStaking/scripts/get_non_operational.cdc"
	getApprovedNodesFileName                    = "idTableStaking/scripts/get_approved_nodes.cdc"
	stakeRequirementsFilename                   = "idTableStaking/scripts/get_stake_requirements.cdc"
	totalStakedByTypeFilename                   = "idTableStaking/scripts/get_total_staked_by_type.cdc"
	totalStakedFilename                         = "idTableStaking/scripts/get_total_staked.cdc"
	rewardRatioFilename                         = "idTableStaking/scripts/get_node_type_ratio.cdc"
	weeklyPayoutFilename                        = "idTableStaking/scripts/get_weekly_payout.cdc"
	getCandidateLimitFilename                   = "idTableStaking/scripts/get_candidate_limit.cdc"
	getCandidateNodesFilename                   = "idTableStaking/scripts/get_candidate_nodes.cdc"
)

// Admin Templates -----------------------------------------------------------

// GenerateTransferMinterAndDeployScript generates a script that transfers
// a flow minter and deploys the id table account
func GenerateTransferMinterAndDeployScript(env Environment) []byte {
	code := assets.MustAssetString(transferDeployFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateRemoveNodeScript creates a script that removes a node
// from the record
func GenerateRemoveNodeScript(env Environment) []byte {
	code := assets.MustAssetString(removeNodeFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateStartStakingScript creates a script that starts the staking auction
func GenerateStartStakingScript(env Environment) []byte {
	code := assets.MustAssetString(startStakingFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateEndStakingScript creates a script that ends the staking auction
func GenerateEndStakingScript(env Environment) []byte {
	code := assets.MustAssetString(endStakingFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateRemoveUnapprovedNodesScript(env Environment) []byte {
	code := assets.MustAssetString(removeUnapprovedNodesFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateSetApprovedNodesScript(env Environment) []byte {
	code := assets.MustAssetString(setApprovedNodesFilename)

	return []byte(ReplaceAddresses(code, env))
}

func NEWGenerateSetApprovedNodesScript(env Environment) []byte {
	code := assets.MustAssetString(NEWsetApprovedNodesFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateAddApprovedNodesScript(env Environment) []byte {
	code := assets.MustAssetString(addApprovedNodesFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateRemoveApprovedNodesScript(env Environment) []byte {
	code := assets.MustAssetString(removeApprovedNodesFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GeneratePayRewardsScript creates a script that pays rewards
func GeneratePayRewardsScript(env Environment) []byte {
	code := assets.MustAssetString(payRewardsFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateMoveTokensScript creates a script that moves tokens between buckets
func GenerateMoveTokensScript(env Environment) []byte {
	code := assets.MustAssetString(moveTokensFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateEndEpochScript(env Environment) []byte {
	code := assets.MustAssetString(endEpochFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateChangeMinimumsScript creates a script that changes the staking minimums
func GenerateChangeMinimumsScript(env Environment) []byte {
	code := assets.MustAssetString(changeMinimumsFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateChangeCutScript creates a script that changes the cut percentage
func GenerateChangeCutScript(env Environment) []byte {
	code := assets.MustAssetString(changeCutFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateChangePayoutScript creates a script that changes the weekly payout
func GenerateChangePayoutScript(env Environment) []byte {
	code := assets.MustAssetString(changePayoutFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateEndEpochChangePayoutScript creates a script that changes the weekly payout
// and then ends the epoch
func GenerateEndEpochChangePayoutScript(env Environment) []byte {
	code := assets.MustAssetString(endEpochChangePayoutFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateUpgradeStakingScript creates a script that upgrades the staking contract
func GenerateUpgradeStakingScript(env Environment) []byte {
	code := assets.MustAssetString(upgradeStakingFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateSetClaimedScript creates a script that sets the new metadata claimed fields
func GenerateSetClaimedScript(env Environment) []byte {
	code := assets.MustAssetString(setClaimedFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateTransferAdminCapabilityScript(env Environment) []byte {
	code := assets.MustAssetString(transferAdminCapabilityFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateCapabilityEndEpochScript(env Environment) []byte {
	code := assets.MustAssetString(capabilityEndEpochFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateTransferFeesAdminScript(env Environment) []byte {
	code := assets.MustAssetString(transferFeesAdminFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateSetNonOperationalScript(env Environment) []byte {
	code := assets.MustAssetString(setNonOperationalFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateSetCandidateLimitScript(env Environment) []byte {
	code := assets.MustAssetString(setCandidateLimitFilename)

	return []byte(ReplaceAddresses(code, env))
}

// For testing only
func GenerateScaleRewardsTestScript(env Environment) []byte {
	code := assets.MustAssetString(scaleRewardsTestFilename)
	return []byte(ReplaceAddresses(code, env))
}

// Node Templates -------------------------------------------------------------

// GenerateRegisterNodeScript creates a script that creates a new
// node struct and stores it in the Node records
func GenerateRegisterNodeScript(env Environment) []byte {
	code := assets.MustAssetString(registerNodeFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateStakeNewTokensScript creates a script that stakes new
// tokens for a node operator
func GenerateStakeNewTokensScript(env Environment) []byte {
	code := assets.MustAssetString(stakeNewTokensFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateStakeUnstakedTokensScript creates a script that stakes
// tokens for a node operator from their unstaked bucket
func GenerateStakeUnstakedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(stakeUnstakedTokensFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateStakeRewardedTokensScript creates a script that stakes
// tokens for a node operator from their rewarded bucket
func GenerateStakeRewardedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(stakeRewardedTokensFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateUnstakeTokensScript creates a script that makes an unstaking request
// for an existing node operator
func GenerateUnstakeTokensScript(env Environment) []byte {
	code := assets.MustAssetString(unstakeTokensFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateUnstakeAllScript creates a script that makes an unstaking request
// for an existing node operator to unstake all their tokens
func GenerateUnstakeAllScript(env Environment) []byte {
	code := assets.MustAssetString(unstakeAllFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateWithdrawUnstakedTokensScript creates a script that withdraws unstaked tokens
// for an existing node operator
func GenerateWithdrawUnstakedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(withdrawUnstakedTokensFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateWithdrawRewardedTokensScript creates a script that withdraws rewarded tokens
// for an existing node operator
func GenerateWithdrawRewardedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(withdrawRewardedTokensFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateUpdateNetworkingAddressScript creates a script changes the networking address
// for an existing node operator
func GenerateUpdateNetworkingAddressScript(env Environment) []byte {
	code := assets.MustAssetString(updateNetworkingAddressFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateAddPublicNodeCapabilityScript(env Environment) []byte {
	code := assets.MustAssetString(addPublicNodeCapabilityFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateReturnTableScript creates a script that returns
// the the whole ID table nodeIDs
func GenerateReturnTableScript(env Environment) []byte {
	code := assets.MustAssetString(getTableFilename)

	return []byte(ReplaceAddresses(code, env))
}

// Staking Data Scripts --------------------------------------------------------

// GenerateGetStakeRequirementsScript returns the stake requirement for a node type
func GenerateGetStakeRequirementsScript(env Environment) []byte {
	code := assets.MustAssetString(stakeRequirementsFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetTotalTokensStakedByTypeScript returns the total tokens staked for a node type
func GenerateGetTotalTokensStakedByTypeScript(env Environment) []byte {
	code := assets.MustAssetString(totalStakedByTypeFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetTotalTokensStakedScript returns the total tokens staked
func GenerateGetTotalTokensStakedScript(env Environment) []byte {
	code := assets.MustAssetString(totalStakedFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetRewardRatioScript gets the reward ratio for a node type
func GenerateGetRewardRatioScript(env Environment) []byte {
	code := assets.MustAssetString(rewardRatioFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetWeeklyPayoutScript gets the total weekly reward payout
func GenerateGetWeeklyPayoutScript(env Environment) []byte {
	code := assets.MustAssetString(weeklyPayoutFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetCutPercentageScript gets the delegator cut percentage
func GenerateGetCutPercentageScript(env Environment) []byte {
	code := assets.MustAssetString(getCutPercentageFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateReturnCurrentTableScript creates a script that returns
// the current ID table
func GenerateReturnCurrentTableScript(env Environment) []byte {
	code := assets.MustAssetString(currentTableFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateReturnProposedTableScript creates a script that returns
// the ID table for the proposed next epoch
func GenerateReturnProposedTableScript(env Environment) []byte {
	code := assets.MustAssetString(proposedTableFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetNodeInfoScript(env Environment) []byte {
	code := assets.MustAssetString(getNodeInfoScript)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetNodeInfoFromAddressScript(env Environment) []byte {
	code := assets.MustAssetString(getNodeInfoFromAddressScript)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetRoleScript creates a script
// that returns the role of a node
func GenerateGetRoleScript(env Environment) []byte {
	code := assets.MustAssetString(getRoleFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetNetworkingAddressScript creates a script
// that returns the networking address of a node
func GenerateGetNetworkingAddressScript(env Environment) []byte {
	code := assets.MustAssetString(getNetworkingAddrFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetNetworkingKeyScript creates a script
// that returns the networking key of a node
func GenerateGetNetworkingKeyScript(env Environment) []byte {
	code := assets.MustAssetString(getNetworkingKeyFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetStakingKeyScript creates a script
// that returns the staking key of a node
func GenerateGetStakingKeyScript(env Environment) []byte {
	code := assets.MustAssetString(getStakingKeyFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetInitialWeightScript creates a script
// that returns the initial weight of a node
func GenerateGetInitialWeightScript(env Environment) []byte {
	code := assets.MustAssetString(getInitialWeightFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetStakedBalanceScript creates a script
// that returns the balance of the staked tokens of a node
func GenerateGetStakedBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(stakedBalanceFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetCommittedBalanceScript creates a script
// that returns the balance of the committed tokens of a node
func GenerateGetCommittedBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(comittedBalanceFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetUnstakingBalanceScript creates a script
// that returns the balance of the unstaking tokens of a node
func GenerateGetUnstakingBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(unstakingBalanceFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetUnstakedBalanceScript creates a script
// that returns the balance of the unstaked tokens of a node
func GenerateGetUnstakedBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(unstakedBalanceFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetRewardBalanceScript creates a script
// that returns the balance of the rewarded tokens of a node
func GenerateGetRewardBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(rewardBalanceFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetUnstakingRequestScript creates a script
// that returns the balance of the unstaking request for a node
func GenerateGetUnstakingRequestScript(env Environment) []byte {
	code := assets.MustAssetString(getUnstakingRequestFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetTotalCommitmentBalanceScript creates a script
// that returns the balance of the total committed tokens of a node plus delegators
func GenerateGetTotalCommitmentBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(getTotalCommitmentFilename)

	return []byte(ReplaceAddresses(code, env))
}

// GenerateGetTotalCommitmentBalanceWithoutDelegatorsScript creates a script
// that returns the balance of the total committed tokens of a node without delegators
func GenerateGetTotalCommitmentBalanceWithoutDelegatorsScript(env Environment) []byte {
	code := assets.MustAssetString(getTotalCommitmentWithoutDelegatorsFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetNonOperationalListScript(env Environment) []byte {
	code := assets.MustAssetString(getNonOperationalListFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetCandidateLimitScript(env Environment) []byte {
	code := assets.MustAssetString(getCandidateLimitFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetCandidateNodesScript(env Environment) []byte {
	code := assets.MustAssetString(getCandidateNodesFilename)

	return []byte(ReplaceAddresses(code, env))
}

// For testing

func GenerateRegisterManyNodesScript(env Environment) []byte {
	code := assets.MustAssetString(registerManyNodesFilename)

	return []byte(ReplaceAddresses(code, env))
}

func GenerateGetApprovedNodesScript(env Environment) []byte {
	code := assets.MustAssetString(getApprovedNodesFileName)

	return []byte(ReplaceAddresses(code, env))
}
