package templates

import (
	"strings"

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
	stakeUnlockedTokensFilename    = "idTableStaking/stake_unlocked_tokens.cdc"
	stakeRewardedTokensFilename    = "idTableStaking/stake_rewarded_tokens.cdc"
	unstakeTokensFilename          = "idTableStaking/request_unstake.cdc"
	withdrawUnlockedTokensFilename = "idTableStaking/withdraw_unlocked_tokens.cdc"
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
	unlockedBalanceFilename     = "idTableStaking/get_node_unlockedTokens.cdc"
	rewardBalanceFilename       = "idTableStaking/get_node_rewardedTokens.cdc"
	unstakedBalanceFilename     = "idTableStaking/get_node_unstakedTokens.cdc"
	getTotalCommitmentFilename  = "idTableStaking/get_node_total_commitment.cdc"
	getUnstakingRequestFilename = "idTableStaking/get_node_unstaking_request.cdc"

	stakeRequirementsFilename = "idTableStaking/get_stakeRequirements.cdc"
	totalStakedFilename       = "idTableStaking/get_totalStaked_by_type.cdc"
	rewardRatioFilename       = "idTableStaking/get_nodeType_ratio.cdc"
	weeklyPayoutFilename      = "idTableStaking/get_weeklyPayout.cdc"

	defaultFTAddress        = "FUNGIBLETOKENADDRESS"
	defaultFlowTokenAddress = "FLOWTOKENADDRESS"
	defaultIDTableAddress   = "IDENTITYTABLEADDRESS"
)

// ReplaceAddresses replaces the import address
// and phase in scripts that return info about a specific node and phase
func ReplaceAddresses(code, ftAddr, flowTokenAddr, idTableAddr string) string {

	code = strings.ReplaceAll(
		code,
		"0x"+defaultFTAddress,
		"0x"+ftAddr,
	)

	code = strings.ReplaceAll(
		code,
		"0x"+defaultFlowTokenAddress,
		"0x"+flowTokenAddr,
	)

	code = strings.ReplaceAll(
		code,
		"0x"+defaultIDTableAddress,
		"0x"+idTableAddr,
	)

	return code
}

// GenerateTransferMinterAndDeployScript generates a script that transfers
// a flow minter and deploys the id table account
func GenerateTransferMinterAndDeployScript(ftAddr, flowAddr string) []byte {
	code := assets.MustAssetString(filePath + transferDeployFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, ""))
}

// GenerateReturnTableScript creates a script that returns
// the the whole ID table nodeIDs
func GenerateReturnTableScript(ftAddr, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getTableFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, idTableAddr))
}

// GenerateReturnCurrentTableScript creates a script that returns
// the current ID table
func GenerateReturnCurrentTableScript(ftAddr, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + currentTableFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, idTableAddr))
}

// GenerateReturnProposedTableScript creates a script that returns
// the ID table for the proposed next epoch
func GenerateReturnProposedTableScript(ftAddr, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + proposedTableFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, idTableAddr))
}

// GenerateCreateNodeScript creates a script that creates a new
// node struct and stores it in the Node records
func GenerateCreateNodeScript(ftAddr, flowAddr, tableAddr string) []byte {
	code := assets.MustAssetString(filePath + createNodeStructFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, tableAddr))
}

// GenerateRemoveNodeScript creates a script that removes a node
// from the record
func GenerateRemoveNodeScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + removeNodeFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateEndStakingScript creates a script that ends the staking auction
func GenerateEndStakingScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + endStakingFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GeneratePayRewardsScript creates a script that pays rewards
func GeneratePayRewardsScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + payRewardsFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateMoveTokensScript creates a script that moves tokens between buckets
func GenerateMoveTokensScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + moveTokensFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateStakeNewTokensScript creates a script that stakes new
// tokens for a node operator
func GenerateStakeNewTokensScript(ftAddr, flowAddr, tableAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeNewTokensFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, tableAddr))
}

// GenerateStakeUnlockedTokensScript creates a script that stakes
// tokens for a node operator from their unlocked bucket
func GenerateStakeUnlockedTokensScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeUnlockedTokensFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateStakeRewardedTokensScript creates a script that stakes
// tokens for a node operator from their rewarded bucket
func GenerateStakeRewardedTokensScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeRewardedTokensFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateUnstakeTokensScript creates a script that makes an unstaking request
// for an existing node operator
func GenerateUnstakeTokensScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + unstakeTokensFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateWithdrawUnlockedTokensScript creates a script that withdraws unlocked tokens
// for an existing node operator
func GenerateWithdrawUnlockedTokensScript(ftAddr, flowAddr, tableAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawUnlockedTokensFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, tableAddr))
}

// GenerateWithdrawRewardedTokensScript creates a script that withdraws rewarded tokens
// for an existing node operator
func GenerateWithdrawRewardedTokensScript(ftAddr, flowAddr, tableAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawRewardedTokensFilename)

	return []byte(ReplaceAddresses(code, ftAddr, flowAddr, tableAddr))
}

// GenerateGetRoleScript creates a script
// that returns the role of a node
func GenerateGetRoleScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getRoleFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetNetworkingAddressScript creates a script
// that returns the networking address of a node
func GenerateGetNetworkingAddressScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getNetworkingAddrFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetNetworkingKeyScript creates a script
// that returns the networking key of a node
func GenerateGetNetworkingKeyScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getNetworkingKeyFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetStakingKeyScript creates a script
// that returns the staking key of a node
func GenerateGetStakingKeyScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getStakingKeyFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetInitialWeightScript creates a script
// that returns the initial weight of a node
func GenerateGetInitialWeightScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getInitialWeightFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetStakedBalanceScript creates a script
// that returns the balance of the staked tokens of a node
func GenerateGetStakedBalanceScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + stakedBalanceFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetCommittedBalanceScript creates a script
// that returns the balance of the committed tokens of a node
func GenerateGetCommittedBalanceScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + comittedBalanceFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetUnstakedBalanceScript creates a script
// that returns the balance of the unstaked tokens of a node
func GenerateGetUnstakedBalanceScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + unstakedBalanceFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetUnlockedBalanceScript creates a script
// that returns the balance of the unlocked tokens of a node
func GenerateGetUnlockedBalanceScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + unlockedBalanceFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetRewardBalanceScript creates a script
// that returns the balance of the rewarded tokens of a node
func GenerateGetRewardBalanceScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + rewardBalanceFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetUnstakingRequestScript creates a script
// that returns the balance of the unstaking request for a node
func GenerateGetUnstakingRequestScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getUnstakingRequestFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetTotalCommitmentBalanceScript creates a script
// that returns the balance of the total committed tokens of a node
func GenerateGetTotalCommitmentBalanceScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + getTotalCommitmentFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetStakeRequirementsScript returns the stake requirement for a node type
func GenerateGetStakeRequirementsScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeRequirementsFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetTotalTokensStakedByTypeScript returns the total tokens staked for a node type
func GenerateGetTotalTokensStakedByTypeScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + totalStakedFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetRewardRatioScript gets the reward ratio for a node type
func GenerateGetRewardRatioScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + rewardRatioFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}

// GenerateGetWeeklyPayoutScript gets the total weekly reward payout
func GenerateGetWeeklyPayoutScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + weeklyPayoutFilename)

	return []byte(ReplaceAddresses(code, "", "", tableAddr))
}
