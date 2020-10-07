package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (

	// node operator templates
	setupNodeAccountFilename   = "stakingProxy/sh_setup_node_account.cdc"
	addNodeInfoFilename        = "stakingProxy/sh_add_node_info.cdc"
	removeNodeInfoFilename     = "stakingProxy/sh_remove_node_info.cdc"
	getNodeInfoFilename        = "stakingProxy/sh_get_node_info.cdc"
	removeStakingProxyFilename = "stakingProxy/sh_remove_staking_proxy.cdc"

	// templates for node operator doing staking actions
	proxyStakeNewTokensFilename      = "stakingProxy/sh_stake_new_tokens.cdc"
	proxyStakeUnstakedTokensFilename = "stakingProxy/sh_stake_unstaked_tokens.cdc"
	proxyRequestUnstakingFilename    = "stakingProxy/sh_request_unstaking.cdc"
	proxyUnstakeAllFilename          = "stakingProxy/sh_unstake_all.cdc"
	proxyWithdrawUnstakedFilename    = "stakingProxy/sh_withdraw_unstaked.cdc"
	proxyWithdrawRewardsFilename     = "stakingProxy/sh_withdraw_rewards.cdc"

	// staking helper templates for the token holder to register their node
	registerNodeFilename = "stakingProxy/sh_register_node.cdc"
)

// SetupNodeAccountScript generates a script that sets up
// a node operator's account to receive staking proxies
func SetupNodeAccountScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + setupNodeAccountFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// AddNodeInfoScript generates a script that adds the node
// operators node info to their account
func AddNodeInfoScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + addNodeInfoFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func RemoveNodeInfoScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + removeNodeInfoFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func GetNodeInfoScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + getNodeInfoFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func RemoveStakingProxyScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + removeStakingProxyFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func ProxyStakeNewTokensScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyStakeNewTokensFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func ProxyStakeUnstakedTokensScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyStakeUnstakedTokensFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func ProxyRequestUnstakingScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyRequestUnstakingFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func ProxyUnstakeAllScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyUnstakeAllFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func ProxyWithdrawRewardsScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyWithdrawRewardsFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

func ProxyWithdrawUnstakedScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyWithdrawUnstakedFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// Transactions for the token holder

func RegisterStakingProxyNodeScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + registerNodeFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}
