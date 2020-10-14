package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// node operator templates
	setupNodeAccountFilename   = "stakingProxy/setup_node_account.cdc"
	addNodeInfoFilename        = "stakingProxy/add_node_info.cdc"
	removeNodeInfoFilename     = "stakingProxy/remove_node_info.cdc"
	getNodeInfoFilename        = "stakingProxy/get_node_info.cdc"
	removeStakingProxyFilename = "stakingProxy/remove_staking_proxy.cdc"

	// templates for node operator doing staking actions
	proxyStakeNewTokensFilename      = "stakingProxy/stake_new_tokens.cdc"
	proxyStakeUnstakedTokensFilename = "stakingProxy/stake_unstaked_tokens.cdc"
	proxyRequestUnstakingFilename    = "stakingProxy/request_unstaking.cdc"
	proxyUnstakeAllFilename          = "stakingProxy/unstake_all.cdc"
	proxyWithdrawUnstakedFilename    = "stakingProxy/withdraw_unstaked.cdc"
	proxyWithdrawRewardsFilename     = "stakingProxy/withdraw_rewards.cdc"

	// staking helper templates for the token holder to register their node
	registerNodeFilename = "stakingProxy/register_node.cdc"
)

// GenerateSetupNodeAccountScript generates a script that sets up
// a node operator's account to receive staking proxies
func GenerateSetupNodeAccountScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + setupNodeAccountFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateAddNodeInfoScript generates a script that adds the node
// operators node info to their account
func GenerateAddNodeInfoScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + addNodeInfoFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func GenerateRemoveNodeInfoScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + removeNodeInfoFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func GenerateGetNodeInfoScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + getNodeInfoFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func GenerateRemoveStakingProxyScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + removeStakingProxyFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func GenerateProxyStakeNewTokensScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyStakeNewTokensFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func GenerateProxyStakeUnstakedTokensScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyStakeUnstakedTokensFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func GenerateProxyRequestUnstakingScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyRequestUnstakingFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func GenerateProxyUnstakeAllScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyUnstakeAllFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func GenerateProxyWithdrawRewardsScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyWithdrawRewardsFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func GenerateProxyWithdrawUnstakedScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyWithdrawUnstakedFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// Transactions for the token holder

func GenerateRegisterStakingProxyNodeScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + registerNodeFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}
