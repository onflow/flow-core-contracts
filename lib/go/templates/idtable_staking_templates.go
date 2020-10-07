package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	transferDeployFilename = "idTableStaking/admin/transfer_minter_deploy.cdc"

	removeNodeFilename = "idTableStaking/admin/remove_node.cdc"
	endStakingFilename = "idTableStaking/admin/end_staking.cdc"
	payRewardsFilename = "idTableStaking/admin/pay_rewards.cdc"
	moveTokensFilename = "idTableStaking/admin/move_tokens.cdc"

	createNodeStructFilename       = "idTableStaking/create_staking_request.cdc"
	stakeNewTokensFilename         = "idTableStaking/stake_new_tokens.cdc"
	stakeUnstakedTokensFilename    = "idTableStaking/stake_unstaked_tokens.cdc"
	stakeRewardedTokensFilename    = "idTableStaking/stake_rewarded_tokens.cdc"
	unstakeTokensFilename          = "idTableStaking/request_unstake.cdc"
	withdrawUnstakedTokensFilename = "idTableStaking/withdraw_unstaked_tokens.cdc"
	withdrawRewardedTokensFilename = "idTableStaking/withdraw_rewarded_tokens.cdc"

	getTableFilename            = "idTableStaking/get_table.cdc"
	currentTableFilename        = "idTableStaking/get_current_table.cdc"
	proposedTableFilename       = "idTableStaking/get_proposed_table.cdc"
	getRoleFilename             = "idTableStaking/get_node_role.cdc"
	getNetworkingAddrFilename   = "idTableStaking/get_node_networking_addr.cdc"
	getNetworkingKeyFilename    = "idTableStaking/get_node_networking_key.cdc"
	getStakingKeyFilename       = "idTableStaking/get_node_staking_key.cdc"
	getInitialWeightFilename    = "idTableStaking/get_node_initial_weight.cdc"
	stakedBalanceFilename       = "idTableStaking/get_node_stakedTokens.cdc"
	comittedBalanceFilename     = "idTableStaking/get_node_committedTokens.cdc"
	unstakedBalanceFilename     = "idTableStaking/get_node_unstakedTokens.cdc"
	rewardBalanceFilename       = "idTableStaking/get_node_rewardedTokens.cdc"
	unstakingBalanceFilename    = "idTableStaking/get_node_unstakingTokens.cdc"
	getTotalCommitmentFilename  = "idTableStaking/get_node_total_commitment.cdc"
	getUnstakingRequestFilename = "idTableStaking/get_node_unstaking_request.cdc"

	stakeRequirementsFilename = "idTableStaking/get_stakeRequirements.cdc"
	totalStakedFilename       = "idTableStaking/get_totalStaked_by_type.cdc"
	rewardRatioFilename       = "idTableStaking/get_nodeType_ratio.cdc"
	weeklyPayoutFilename      = "idTableStaking/get_weeklyPayout.cdc"
)

// TransferMinterAndDeployScript generates a script that transfers
// a flow minter and deploys the id table account
func TransferMinterAndDeployScript(ftAddr, flowAddr string) []byte {
	code := assets.MustAssetString(filePath + transferDeployFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, ""))
}

// ReturnTableScript creates a script that returns
// the the whole ID table nodeIDs
func ReturnTableScript(ftAddr, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getTableFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, idTableAddr))
}

// ReturnCurrentTableScript creates a script that returns
// the current ID table
func ReturnCurrentTableScript(ftAddr, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + currentTableFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, idTableAddr))
}

// ReturnProposedTableScript creates a script that returns
// the ID table for the proposed next epoch
func ReturnProposedTableScript(ftAddr, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + proposedTableFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, idTableAddr))
}

// CreateNodeScript creates a script that creates a new
// node struct and stores it in the Node records
func CreateNodeScript(ftAddr, flowAddr, tableAddr string) []byte {
	code := assets.MustAssetString(filePath + createNodeStructFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, tableAddr))
}

// RemoveNodeScript creates a script that removes a node
// from the record
func RemoveNodeScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + removeNodeFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// EndStakingScript creates a script that ends the staking auction
func EndStakingScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + endStakingFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// PayRewardsScript creates a script that pays rewards
func PayRewardsScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + payRewardsFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// MoveTokensScript creates a script that moves tokens between buckets
func MoveTokensScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + moveTokensFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// StakeNewTokensScript creates a script that stakes new
// tokens for a node operator
func StakeNewTokensScript(ftAddr, flowAddr, tableAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeNewTokensFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, tableAddr))
}

// StakeUnstakedTokensScript creates a script that stakes
// tokens for a node operator from their unstaked bucket
func StakeUnstakedTokensScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeUnstakedTokensFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// StakeRewardedTokensScript creates a script that stakes
// tokens for a node operator from their rewarded bucket
func StakeRewardedTokensScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeRewardedTokensFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// UnstakeTokensScript creates a script that makes an unstaking request
// for an existing node operator
func UnstakeTokensScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + unstakeTokensFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// WithdrawUnstakedTokensScript creates a script that withdraws unstaked tokens
// for an existing node operator
func WithdrawUnstakedTokensScript(ftAddr, flowAddr, tableAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawUnstakedTokensFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, tableAddr))
}

// WithdrawRewardedTokensScript creates a script that withdraws rewarded tokens
// for an existing node operator
func WithdrawRewardedTokensScript(ftAddr, flowAddr, tableAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawRewardedTokensFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, tableAddr))
}

// GetRoleScript creates a script
// that returns the role of a node
func GetRoleScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getRoleFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetNetworkingAddressScript creates a script
// that returns the networking address of a node
func GetNetworkingAddressScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getNetworkingAddrFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetNetworkingKeyScript creates a script
// that returns the networking key of a node
func GetNetworkingKeyScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getNetworkingKeyFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetStakingKeyScript creates a script
// that returns the staking key of a node
func GetStakingKeyScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getStakingKeyFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetInitialWeightScript creates a script
// that returns the initial weight of a node
func GetInitialWeightScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getInitialWeightFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetStakedBalanceScript creates a script
// that returns the balance of the staked tokens of a node
func GetStakedBalanceScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + stakedBalanceFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetCommittedBalanceScript creates a script
// that returns the balance of the committed tokens of a node
func GetCommittedBalanceScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + comittedBalanceFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetUnstakingBalanceScript creates a script
// that returns the balance of the unstaking tokens of a node
func GetUnstakingBalanceScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + unstakingBalanceFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetUnstakedBalanceScript creates a script
// that returns the balance of the unstaked tokens of a node
func GetUnstakedBalanceScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + unstakedBalanceFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetRewardBalanceScript creates a script
// that returns the balance of the rewarded tokens of a node
func GetRewardBalanceScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + rewardBalanceFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetUnstakingRequestScript creates a script
// that returns the balance of the unstaking request for a node
func GetUnstakingRequestScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getUnstakingRequestFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetTotalCommitmentBalanceScript creates a script
// that returns the balance of the total committed tokens of a node
func GetTotalCommitmentBalanceScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getTotalCommitmentFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetStakeRequirementsScript returns the stake requirement for a node type
func GetStakeRequirementsScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeRequirementsFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetTotalTokensStakedByTypeScript returns the total tokens staked for a node type
func GetTotalTokensStakedByTypeScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + totalStakedFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetRewardRatioScript gets the reward ratio for a node type
func GetRewardRatioScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + rewardRatioFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GetWeeklyPayoutScript gets the total weekly reward payout
func GetWeeklyPayoutScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + weeklyPayoutFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}
