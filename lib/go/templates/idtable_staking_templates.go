package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	transferDeployFilename = "idTableStaking/admin/transfer_minter_deploy.cdc"

	removeNodeFilename     = "idTableStaking/admin/remove_node.cdc"
	endStakingFilename     = "idTableStaking/admin/end_staking.cdc"
	payRewardsFilename     = "idTableStaking/admin/pay_rewards.cdc"
	moveTokensFilename     = "idTableStaking/admin/move_tokens.cdc"
	endEpochFilename       = "idTableStaking/admin/end_epoch.cdc"
	changeMinimumsFilename = "idTableStaking/admin/change_minimums.cdc"
	changeCutFilename      = "idTableStaking/admin/change_cut.cdc"
	changePayoutFilename   = "idTableStaking/admin/change_payout.cdc"

	registerNodeFilename           = "idTableStaking/register_node.cdc"
	stakeNewTokensFilename         = "idTableStaking/stake_new_tokens.cdc"
	stakeUnstakedTokensFilename    = "idTableStaking/stake_unstaked_tokens.cdc"
	stakeRewardedTokensFilename    = "idTableStaking/stake_rewarded_tokens.cdc"
	unstakeTokensFilename          = "idTableStaking/request_unstake.cdc"
	unstakeAllFilename             = "idTableStaking/unstake_all.cdc"
	withdrawUnstakedTokensFilename = "idTableStaking/withdraw_unstaked_tokens.cdc"
	withdrawRewardedTokensFilename = "idTableStaking/withdraw_rewarded_tokens.cdc"

	registerManyNodesFilename = "idTableStaking/register_many_nodes.cdc"

	getTableFilename                            = "idTableStaking/get_table.cdc"
	currentTableFilename                        = "idTableStaking/get_current_table.cdc"
	proposedTableFilename                       = "idTableStaking/get_proposed_table.cdc"
	getRoleFilename                             = "idTableStaking/get_node_role.cdc"
	getNetworkingAddrFilename                   = "idTableStaking/get_node_networking_addr.cdc"
	getNetworkingKeyFilename                    = "idTableStaking/get_node_networking_key.cdc"
	getStakingKeyFilename                       = "idTableStaking/get_node_staking_key.cdc"
	getInitialWeightFilename                    = "idTableStaking/get_node_initial_weight.cdc"
	stakedBalanceFilename                       = "idTableStaking/get_node_staked_tokens.cdc"
	comittedBalanceFilename                     = "idTableStaking/get_node_committed_tokens.cdc"
	unstakedBalanceFilename                     = "idTableStaking/get_node_unstaked_tokens.cdc"
	rewardBalanceFilename                       = "idTableStaking/get_node_rewarded_tokens.cdc"
	unstakingBalanceFilename                    = "idTableStaking/get_node_unstaking_tokens.cdc"
	getTotalCommitmentFilename                  = "idTableStaking/get_node_total_commitment.cdc"
	getTotalCommitmentWithoutDelegatorsFilename = "idTableStaking/get_node_total_commitment_without_delegators.cdc"
	getUnstakingRequestFilename                 = "idTableStaking/get_node_unstaking_request.cdc"
	getCutPercentageFilename                    = "idTableStaking/get_cut_percentage.cdc"

	stakeRequirementsFilename = "idTableStaking/get_stake_requirements.cdc"
	totalStakedByTypeFilename = "idTableStaking/get_total_staked_by_type.cdc"
	totalStakedFilename       = "idTableStaking/get_total_staked.cdc"
	rewardRatioFilename       = "idTableStaking/get_node_type_ratio.cdc"
	weeklyPayoutFilename      = "idTableStaking/get_weekly_payout.cdc"
)

// Admin Templates -----------------------------------------------------------

// GenerateTransferMinterAndDeployScript generates a script that transfers
// a flow minter and deploys the id table account
func GenerateTransferMinterAndDeployScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + transferDeployFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateRemoveNodeScript creates a script that removes a node
// from the record
func GenerateRemoveNodeScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + removeNodeFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateEndStakingScript creates a script that ends the staking auction
func GenerateEndStakingScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + endStakingFilename)

	return []byte(replaceAddresses(code, env))
}

// GeneratePayRewardsScript creates a script that pays rewards
func GeneratePayRewardsScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + payRewardsFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateMoveTokensScript creates a script that moves tokens between buckets
func GenerateMoveTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + moveTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateEndEpochScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + endEpochFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateChangeMinimumsScript creates a script that changes the staking minimums
func GenerateChangeMinimumsScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + changeMinimumsFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateChangeCutScript creates a script that changes the cut percentage
func GenerateChangeCutScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + changeCutFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateChangePayoutScript creates a script that changes the weekly payout
func GenerateChangePayoutScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + changePayoutFilename)

	return []byte(replaceAddresses(code, env))
}

// Staker Templates -------------------------------------------------------------

// GenerateRegisterNodeScript creates a script that creates a new
// node struct and stores it in the Node records
func GenerateRegisterNodeScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + registerNodeFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateStakeNewTokensScript creates a script that stakes new
// tokens for a node operator
func GenerateStakeNewTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + stakeNewTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateStakeUnstakedTokensScript creates a script that stakes
// tokens for a node operator from their unstaked bucket
func GenerateStakeUnstakedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + stakeUnstakedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateStakeRewardedTokensScript creates a script that stakes
// tokens for a node operator from their rewarded bucket
func GenerateStakeRewardedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + stakeRewardedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateUnstakeTokensScript creates a script that makes an unstaking request
// for an existing node operator
func GenerateUnstakeTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + unstakeTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateUnstakeAllScript creates a script that makes an unstaking request
// for an existing node operator to unstake all their tokens
func GenerateUnstakeAllScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + unstakeAllFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateWithdrawUnstakedTokensScript creates a script that withdraws unstaked tokens
// for an existing node operator
func GenerateWithdrawUnstakedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + withdrawUnstakedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateWithdrawRewardedTokensScript creates a script that withdraws rewarded tokens
// for an existing node operator
func GenerateWithdrawRewardedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + withdrawRewardedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateReturnTableScript creates a script that returns
// the the whole ID table nodeIDs
func GenerateReturnTableScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getTableFilename)

	return []byte(replaceAddresses(code, env))
}

// Staking Data Scripts --------------------------------------------------------

// GenerateGetStakeRequirementsScript returns the stake requirement for a node type
func GenerateGetStakeRequirementsScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + stakeRequirementsFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetTotalTokensStakedByTypeScript returns the total tokens staked for a node type
func GenerateGetTotalTokensStakedByTypeScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + totalStakedByTypeFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetTotalTokensStakedScript returns the total tokens staked
func GenerateGetTotalTokensStakedScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + totalStakedFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetRewardRatioScript gets the reward ratio for a node type
func GenerateGetRewardRatioScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + rewardRatioFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetWeeklyPayoutScript gets the total weekly reward payout
func GenerateGetWeeklyPayoutScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + weeklyPayoutFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetCutPercentageScript gets the delegator cut percentage
func GenerateGetCutPercentageScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getCutPercentageFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateReturnCurrentTableScript creates a script that returns
// the current ID table
func GenerateReturnCurrentTableScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + currentTableFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateReturnProposedTableScript creates a script that returns
// the ID table for the proposed next epoch
func GenerateReturnProposedTableScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + proposedTableFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetRoleScript creates a script
// that returns the role of a node
func GenerateGetRoleScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getRoleFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetNetworkingAddressScript creates a script
// that returns the networking address of a node
func GenerateGetNetworkingAddressScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getNetworkingAddrFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetNetworkingKeyScript creates a script
// that returns the networking key of a node
func GenerateGetNetworkingKeyScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getNetworkingKeyFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetStakingKeyScript creates a script
// that returns the staking key of a node
func GenerateGetStakingKeyScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getStakingKeyFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetInitialWeightScript creates a script
// that returns the initial weight of a node
func GenerateGetInitialWeightScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getInitialWeightFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetStakedBalanceScript creates a script
// that returns the balance of the staked tokens of a node
func GenerateGetStakedBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + stakedBalanceFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetCommittedBalanceScript creates a script
// that returns the balance of the committed tokens of a node
func GenerateGetCommittedBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + comittedBalanceFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetUnstakingBalanceScript creates a script
// that returns the balance of the unstaking tokens of a node
func GenerateGetUnstakingBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + unstakingBalanceFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetUnstakedBalanceScript creates a script
// that returns the balance of the unstaked tokens of a node
func GenerateGetUnstakedBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + unstakedBalanceFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetRewardBalanceScript creates a script
// that returns the balance of the rewarded tokens of a node
func GenerateGetRewardBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + rewardBalanceFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetUnstakingRequestScript creates a script
// that returns the balance of the unstaking request for a node
func GenerateGetUnstakingRequestScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getUnstakingRequestFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetTotalCommitmentBalanceScript creates a script
// that returns the balance of the total committed tokens of a node plus delegators
func GenerateGetTotalCommitmentBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getTotalCommitmentFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetTotalCommitmentBalanceWithoutDelegatorsScript creates a script
// that returns the balance of the total committed tokens of a node without delegators
func GenerateGetTotalCommitmentBalanceWithoutDelegatorsScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getTotalCommitmentWithoutDelegatorsFilename)

	return []byte(replaceAddresses(code, env))
}

// For testing

func GenerateRegisterManyNodesScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + registerManyNodesFilename)

	return []byte(replaceAddresses(code, env))
}
