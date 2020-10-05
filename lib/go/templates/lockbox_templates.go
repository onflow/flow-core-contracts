package templates

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// admin templates
	createAdminCollectionFilename = "lockedTokens/admin/create_admin_collection.cdc"
	createLockedAccountsFilename  = "lockedTokens/admin/create_shared_account.cdc"
	depositLockedTokensFilename   = "lockedTokens/admin/deposit_locked_tokens.cdc"
	increaseUnlockLimitFilename   = "lockedTokens/admin/unlock_tokens.cdc"

	// user templates
	withdrawTokensFilename = "lockedTokens/user/withdraw_tokens.cdc"
	depositTokensFilename  = "lockedTokens/user/deposit_tokens.cdc"
	getUnlockLimitFilename = "lockedTokens/user/get_unlock_limit.cdc"

	// staker templates
	createLockedNodeFilename             = "lockedTokens/staker/register_node.cdc"
	stakeNewLockedTokensFilename         = "lockedTokens/staker/stake_new_tokens.cdc"
	stakeLockedUnlockedTokensFilename    = "lockedTokens/staker/stake_unlocked_tokens.cdc"
	stakeLockedRewardedTokensFilename    = "lockedTokens/staker/stake_rewarded_tokens.cdc"
	unstakeLockedTokensFilename          = "lockedTokens/staker/request_unstaking.cdc"
	unstakeAllLockedTokensFilename       = "lockedTokens/staker/unstake_all.cdc"
	withdrawLockedUnlockedTokensFilename = "lockedTokens/staker/withdraw_unlocked_tokens.cdc"
	withdrawLockedRewardedTokensFilename = "lockedTokens/staker/withdraw_rewarded_tokens.cdc"

	// delegator templates
	registerLockedDelegatorFilename               = "lockedTokens/delegator/register_delegator.cdc"
	delegateNewLockedTokensFilename               = "lockedTokens/delegator/delegate_new_locked_tokens.cdc"
	delegateLockedUnlockedTokensFilename          = "lockedTokens/delegator/delegate_locked_unlocked_tokens.cdc"
	delegateLockedRewardedTokensFilename          = "lockedTokens/delegator/delegate_locked_rewarded_tokens.cdc"
	requestUnstakingLockedDelegatedTokensFilename = "lockedTokens/delegator/request_unstaking_locked_delegated_tokens.cdc"
	withdrawLockedUnlockedDelegatedTokensFilename = "lockedTokens/delegator/withdraw_locked_unlocked_delegated_tokens.cdc"
	withdrawLockedRewardedDelegatedTokensFilename = "lockedTokens/delegator/withdraw_locked_rewarded_delegated_tokens.cdc"

	// addresses
	defaultLockedTokensAddress = "0xf3fcd2c1a78f5eee"
)

// ReplaceLockedTokensAddress replaces the import address
// and phase in scripts that return info about a specific node and phase.
func ReplaceLockedTokensAddress(code, lockedTokensAddress string) string {

	code = strings.ReplaceAll(
		code,
		"0x"+defaultLockedTokensAddress,
		"0x"+lockedTokensAddress,
	)

	return code
}

/************ LockedTokens Admin Transactions ****************/

func GenerateCreateAdminCollectionScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + createAdminCollectionFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func GenerateCreateSharedAccountScript(ftAddr, flowTokenAddr, lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + createLockedAccountsFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func GenerateDepositLockedTokensScript(ftAddr, flowTokenAddr, lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + depositLockedTokensFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func GenerateIncreaseUnlockLimitScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + increaseUnlockLimitFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

/************ User Transactions ********************/

func GenerateWithdrawTokensScript(ftAddr, flowTokenAddr, lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawTokensFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func GenerateDepositTokensScript(ftAddr, flowTokenAddr, lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + depositTokensFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func GenerateGetUnlockLimitScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + getUnlockLimitFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

/************ Node Staker Transactions ******************/

// GenerateCreateLockedNodeScript creates a script that creates a new
// node request with locked tokens.
func GenerateCreateLockedNodeScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + createLockedNodeFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateStakeNewLockedTokensScript creates a script that stakes new
// locked tokens.
func GenerateStakeNewLockedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeNewLockedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateStakeLockedUnlockedTokensScript creates a script that stakes
// unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateStakeLockedUnlockedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeLockedUnlockedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateStakeLockedRewardedTokensScript creates a script that stakes
// unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateStakeLockedRewardedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeLockedRewardedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateUnstakeLockedTokensScript creates a script that unstakes
// locked tokens.
func GenerateUnstakeLockedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + unstakeLockedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateUnstakeAllLockedTokensScript creates a script that unstakes
// all locked tokens.
func GenerateUnstakeAllLockedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + unstakeAllLockedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateWithdrawLockedUnlockedTokensScript creates a script that requests
// a withdrawal of unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawLockedUnlockedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedUnlockedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateWithdrawLockedRewardedTokensScript creates a script that requests
// a withdrawal of unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawLockedRewardedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedRewardedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

/******************** Delegator Transactions ****************************/

// GenerateCreateLockedDelegatorScript creates a script that creates a new
// node request with locked tokens.
func GenerateCreateLockedDelegatorScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + registerLockedDelegatorFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateDelegateNewLockedTokensScript creates a script that stakes new
// locked tokens.
func GenerateDelegateNewLockedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + delegateNewLockedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateDelegateLockedUnlockedTokensScript creates a script that stakes
// unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateDelegateLockedUnlockedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + delegateLockedUnlockedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateDelegateLockedRewardedTokensScript creates a script that stakes
// unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateDelegateLockedRewardedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + delegateLockedRewardedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateUnDelegateLockedTokensScript creates a script that unstakes
// locked tokens.
func GenerateUnDelegateLockedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + requestUnstakingLockedDelegatedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateWithdrawDelegatorLockedUnlockedTokensScript creates a script that requests
// a withdrawal of unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawDelegatorLockedUnlockedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedUnlockedDelegatedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateWithdrawDelegatorLockedRewardedTokensScript creates a script that requests
// a withdrawal of unlocked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawDelegatorLockedRewardedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedRewardedDelegatedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}
