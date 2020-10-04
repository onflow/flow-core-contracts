package templates

import (
	"strings"

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
	proxyStakeUnlockedTokensFilename = "stakingProxy/sh_stake_unlocked_tokens.cdc"
	proxyRequestUnstakingFilename    = "stakingProxy/sh_request_unstaking.cdc"
	proxyUnstakeAllFilename          = "stakingProxy/sh_unstake_all.cdc"
	proxyWithdrawUnlockedFilename    = "stakingProxy/sh_withdraw_unlocked.cdc"
	proxyWithdrawRewardsFilename     = "stakingProxy/sh_withdraw_rewards.cdc"

	// staking helper templates for the token holder to register their node
	registerNodeFilename = "stakingProxy/sh_register_node.cdc"

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

func GenerateProxyStakeUnlockedTokensScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyStakeUnlockedTokensFilename)

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

func GenerateProxyWithdrawUnlockedScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + proxyWithdrawUnlockedFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// Transactions for the token holder

func GenerateRegisterStakingProxyNodeScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + registerNodeFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}
