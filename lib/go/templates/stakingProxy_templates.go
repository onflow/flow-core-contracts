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
func GenerateSetupNodeAccountScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + setupNodeAccountFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateAddNodeInfoScript generates a script that adds the node
// operators node info to their account
func GenerateAddNodeInfoScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + addNodeInfoFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateRemoveNodeInfoScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + removeNodeInfoFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetNodeInfoScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getNodeInfoFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateRemoveStakingProxyScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + removeStakingProxyFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateProxyStakeNewTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + proxyStakeNewTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateProxyStakeUnstakedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + proxyStakeUnstakedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateProxyRequestUnstakingScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + proxyRequestUnstakingFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateProxyUnstakeAllScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + proxyUnstakeAllFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateProxyWithdrawRewardsScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + proxyWithdrawRewardsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateProxyWithdrawUnstakedScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + proxyWithdrawUnstakedFilename)

	return []byte(replaceAddresses(code, env))
}

// Transactions for the token holder

func GenerateRegisterStakingProxyNodeScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + registerNodeFilename)

	return []byte(replaceAddresses(code, env))
}
