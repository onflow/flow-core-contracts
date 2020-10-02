package templates

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// admin templates
	createAdminCollectionFilename = "lockbox/admin/create_admin_collection.cdc"
	createLockedAccountsFilename  = "lockbox/admin/create_shared_account.cdc"

	// staker templates
	createLockedNodeFilename             = "lockbox/staker/register_node.cdc"
	stakeNewLockedTokensFilename         = "lockbox/staker/stake_new_tokens.cdc"
	stakeLockedUnlockedTokensFilename    = "lockbox/staker/stake_unlocked_tokens.cdc"
	stakeLockedRewardedTokensFilename    = "lockbox/staker/stake_rewarded_tokens.cdc"
	unstakeLockedTokensFilename          = "lockbox/staker/request_unstaking.cdc"
	withdrawLockedUnlockedTokensFilename = "lockbox/staker/withdraw_unlocked_tokens.cdc"
	withdrawLockedRewardedTokensFilename = "lockbox/staker/withdraw_rewarded_tokens.cdc"

	// delegator templates
	registerLockedDelegatorFilename               = "lockbox/delegator/register_delegator.cdc"
	delegateNewLockedTokensFilename               = "lockbox/delegator/"
	delegateLockedUnlockedTokensFilename          = "lockbox/delegator/"
	delegateLockedRewardedTokensFilename          = "lockbox/delegator/"
	requestUnstakingLockedDelegatedTokensFilename = "lockbox/delegator/"
	unstakeAllLockedDelegatedTokensFilename       = "lockbox/delegator/"
	withdrawLockedUnlockedDelegatedTokensFilename = "lockbox/delegator/"
	withdrawLockedRewardedDelegatedTokensFilename = "lockbox/delegator/"

	// staking helper templates
	registerNodeFilename = "stakingProxy/stakingHelper/sh_register_node.cdc"

	// addresses
	defaultLockboxAddress = "0xf3fcd2c1a78f5eee"
)

// ReplaceLockboxAddress replaces the import address
// and phase in scripts that return info about a specific node and phase.
func ReplaceLockboxAddress(code, lockboxAddress string) string {

	code = strings.ReplaceAll(
		code,
		"0x"+defaultLockboxAddress,
		"0x"+lockboxAddress,
	)

	return code
}

// GenerateCreateLockedNodeScript creates a script that creates a new
// node request with locked tokens.
func GenerateCreateLockedNodeScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + createLockedNodeFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateStakeNewLockedTokensScript creates a script that stakes new
// locked tokens.
func GenerateStakeNewLockedTokensScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeNewLockedTokensFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateStakeLockedUnlockedTokensScript creates a script that stakes
// unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateStakeLockedUnlockedTokensScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeLockedUnlockedTokensFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateStakeLockedRewardedTokensScript creates a script that stakes
// unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateStakeLockedRewardedTokensScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeLockedUnlockedTokensFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateUnstakeLockedTokensScript creates a script that unstakes
// locked tokens.
func GenerateUnstakeLockedTokensScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + unstakeLockedTokensFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateWithdrawLockedUnlockedTokensScript creates a script that requests
// a withdrawal of unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawLockedUnlockedTokensScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedUnlockedTokensFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateWithdrawLockedRewardedTokensScript creates a script that requests
// a withdrawal of unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawLockedRewardedTokensScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedRewardedTokensFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}
