package templates

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (

	// node operator templates
	setupNodeAccountFilename   = "stakingProxy/setup_node_account.cdc"
	addNodeInfoFilename        = "stakingProxy/add_node_info.cdc"
	removeNodeInfoFilename     = "stakingProxy/remove_node_info.cdc"
	removeStakingProxyFilename = "stakingProxy/remove_staking_proxy.cdc"

	// templates for node operator doing staking actions
	proxyStakeNewTokensFilename      = "stakingProxy/proxy_stake_new_tokens.cdc"
	proxyStakeUnlockedTokensFilename = "stakingProxy/proxy_stake_unlocked_tokens.cdc"
	proxyRequestUnstakingFilename    = "stakingProxy/proxy_request_unstaking.cdc"
	proxyUnstakeAllFilename          = "stakingProxy/proxy_unstake_all.cdc"
	proxyWithdrawUnlockedFilename    = "stakingProxy/proxy_withdraw_unlocked.cdc"
	proxyWithdrawRewardsFilename     = "stakingProxy/proxy_withdraw_rewards.cdc"

	// addresses
	defaultStakingProxyAddress = "0x179b6b1cb6755e31"
)

// ReplaceStakingProxyAddress replaces the import address
// and phase in scripts that use staking proxy contract
func ReplaceStakingProxyAddress(code, proxyAddr string) string {

	code = strings.ReplaceAll(
		code,
		"0x"+defaultStakingProxyAddress,
		"0x"+proxyAddr,
	)

	return code
}

// GenerateSetupNodeAccountScript generates a script that sets up
// a node operator's account to receive staking proxies.
func GenerateSetupNodeAccountScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + setupNodeAccountFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateAddNodeInfoScript generates a script that adds a
// NodeInfo to a node operator's NodeStakerProxyHolder.
func GenerateAddNodeInfoScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + addNodeInfoFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateRemoveNodeInfoScript generates a script that removes a
// NodeInfo from a node operator's NodeStakerProxyHolder.
func GenerateRemoveNodeInfoScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + removeNodeInfoFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateRemoveStakingProxyScript generates a script that removes a
// staking proxy from a node operator's NodeStakerProxyHolder.
func GenerateRemoveStakingProxyScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + removeStakingProxyFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateProxyStakeNewTokensScript generates a script that stakes
// new tokens for the admin via their NodeStakerProxyHolder.
func GenerateProxyStakeNewTokensScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyStakeNewTokensFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateProxyStakeUnlockedTokensScript generates a script that stakes
// unlocked tokens for the admin via their NodeStakerProxyHolder.
func GenerateProxyStakeUnlockedTokensScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyStakeUnlockedTokensFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateProxyRequestUnstakingScript generates a script that requests
// that staked tokens be unstaked for the admin via their NodeStakerProxyHolder.
func GenerateProxyRequestUnstakingScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyRequestUnstakingFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateProxyUnstakeAllScript generates a script that unstakes
// an amount of all tokens for the admin via their NodeStakerProxyHolder.
func GenerateProxyUnstakeAllScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyUnstakeAllFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateProxyWithdrawUnlockedScript generates a script that withdraws
// an amount of unlocked tokens for the admin via their NodeStakerProxyHolder.
func GenerateProxyWithdrawUnlockedScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyWithdrawUnlockedFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateProxyWithdrawRewardsScript generates a script that withdraws
// an amount of rewarded tokens for the admin via their NodeStakerProxyHolder.
func GenerateProxyWithdrawRewardsScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyWithdrawRewardsFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}
