package templates

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// admin templates
	createAdminCollectionFilename = "lockbox/admin/create_admin_collection.cdc"
	createLockedAccountsFilename  = "lockbox/admin/create_shared_account.cdc"
	depositLockedTokensFilename   = "lockbox/admin/deposit_locked_tokens.cdc"
	increaseUnlockLimitFilename   = "lockbox/admin/unlock_tokens.cdc"

	// user templates
	withdrawTokensFilename = "lockbox/user/withdraw_tokens.cdc"
	depositTokensFilename  = "lockbox/user/deposit_tokens.cdc"
	getUnlockLimitFilename = "lockbox/user/get_unlock_limit.cdc"

	// staker templates
	createLockedNodeFilename             = "lockbox/staker/register_node.cdc"
	stakeNewLockedTokensFilename         = "lockbox/staker/stake_new_tokens.cdc"
	stakeLockedUnlockedTokensFilename    = "lockbox/staker/stake_unlocked_tokens.cdc"
	stakeLockedRewardedTokensFilename    = "lockbox/staker/stake_rewarded_tokens.cdc"
	unstakeLockedTokensFilename          = "lockbox/staker/request_unstaking.cdc"
	unstakeAllLockedTokensFilename       = "lockbox/staker/unstake_all.cdc"
	withdrawLockedUnlockedTokensFilename = "lockbox/staker/withdraw_unlocked_tokens.cdc"
	withdrawLockedRewardedTokensFilename = "lockbox/staker/withdraw_rewarded_tokens.cdc"

	// delegator templates
	registerLockedDelegatorFilename               = "lockbox/delegator/register_delegator.cdc"
	delegateNewLockedTokensFilename               = "lockbox/delegator/delegate_new_locked_tokens.cdc"
	delegateLockedUnlockedTokensFilename          = "lockbox/delegator/delegate_locked_unlocked_tokens.cdc"
	delegateLockedRewardedTokensFilename          = "lockbox/delegator/delegate_locked_rewarded_tokens.cdc"
	requestUnstakingLockedDelegatedTokensFilename = "lockbox/delegator/request_unstaking_locked_delegated_tokens.cdc"
	withdrawLockedUnlockedDelegatedTokensFilename = "lockbox/delegator/withdraw_locked_unlocked_delegated_tokens.cdc"
	withdrawLockedRewardedDelegatedTokensFilename = "lockbox/delegator/withdraw_locked_rewarded_delegated_tokens.cdc"

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

/************ Lockbox Admin Transactions ****************/

func GenerateCreateAdminCollectionScript(lockboxAddr string) []byte {
	code := assets.MustAssetString(filePath + createAdminCollectionFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(code)
}

func GenerateCreateSharedAccountScript(ftAddr, flowTokenAddr, lockboxAddr string) []byte {
	code := assets.MustAssetString(filePath + createLockedAccountsFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(code)
}

func GenerateDepositLockedTokensScript(ftAddr, flowTokenAddr, lockboxAddr string) []byte {
	code := assets.MustAssetString(filePath + depositLockedTokensFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(code)
}

func GenerateIncreaseUnlockLimitScript(lockboxAddr string) []byte {
	code := assets.MustAssetString(filePath + increaseUnlockLimitFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(code)
}

/************ User Transactions ********************/

func GenerateWithdrawTokensScript(ftAddr, flowTokenAddr, lockboxAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawTokensFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(code)
}

func GenerateDepositTokensScript(ftAddr, flowTokenAddr, lockboxAddr string) []byte {
	code := assets.MustAssetString(filePath + depositTokensFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(code)
}

func GenerateGetUnlockLimitScript(lockboxAddr string) []byte {
	code := assets.MustAssetString(filePath + getUnlockLimitFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(code)
}

/************ Node Staker Transactions ******************/

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

// GenerateUnstakeAllLockedTokensScript creates a script that unstakes
// all locked tokens.
func GenerateUnstakeAllLockedTokensScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + unstakeAllLockedTokensFilename)

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

/******************** Delegator Transactions ****************************/

// GenerateCreateLockedDelegatorScript creates a script that creates a new
// node request with locked tokens.
func GenerateCreateLockedDelegatorScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + registerLockedDelegatorFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateDelegateNewLockedTokensScript creates a script that stakes new
// locked tokens.
func GenerateDelegateNewLockedTokensScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + delegateNewLockedTokensFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateDelegateLockedUnlockedTokensScript creates a script that stakes
// unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateDelegateLockedUnlockedTokensScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + delegateLockedUnlockedTokensFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateDelegateLockedRewardedTokensScript creates a script that stakes
// unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateDelegateLockedRewardedTokensScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + delegateLockedRewardedTokensFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateUnDelegateLockedTokensScript creates a script that unstakes
// locked tokens.
func GenerateUnDelegateLockedTokensScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + requestUnstakingLockedDelegatedTokensFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateWithdrawDelegatorLockedUnlockedTokensScript creates a script that requests
// a withdrawal of unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawDelegatorLockedUnlockedTokensScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedUnlockedDelegatedTokensFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateWithdrawDelegatorLockedRewardedTokensScript creates a script that requests
// a withdrawal of unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawDelegatorLockedRewardedTokensScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedRewardedDelegatedTokensFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}
