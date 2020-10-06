package templates

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// admin templates
	createAdminCollectionFilename           = "lockedTokens/admin/create_admin_collection.cdc"
	createLockedAccountsFilename            = "lockedTokens/admin/admin_create_shared_accounts.cdc"
	depositLockedTokensFilename             = "lockedTokens/admin/deposit_locked_tokens.cdc"
	increaseUnlockLimitFilename             = "lockedTokens/admin/unlock_tokens.cdc"
	depositAccountCreatorCapabilityFilename = "lockedTokens/admin/admin_deposit_account_creator.cdc"

	// Custody Provider / Wallet provider Account creation templates
	setupCustodyAccountFilename            = "lockedTokens/admin/custody_setup_account_creator.cdc"
	custodyCreateAccountsFilename          = "lockedTokens/admin/custody_create_shared_accounts.cdc"
	custodyCreateOnlySharedAccountFilename = "lockedTokens/admin/custody_create_only_shared_account.cdc"

	// user templates
	withdrawTokensFilename = "lockedTokens/user/withdraw_tokens.cdc"
	depositTokensFilename  = "lockedTokens/user/deposit_tokens.cdc"
	getLockedAccountAddressFilename = "lockedTokens/user/get_locked_account_address.cdc"
	getBalanceFilename = "lockedTokens/user/get_locked_account_balance.cdc"
	getUnlockLimitFilename = "lockedTokens/user/get_unlock_limit.cdc"

	// staker templates
	createLockedNodeFilename             = "lockedTokens/staker/register_node.cdc"
	stakeNewLockedTokensFilename         = "lockedTokens/staker/stake_new_tokens.cdc"
	stakeLockedUnstakedTokensFilename    = "lockedTokens/staker/stake_unstaked_tokens.cdc"
	stakeLockedRewardedTokensFilename    = "lockedTokens/staker/stake_rewarded_tokens.cdc"
	unstakeLockedTokensFilename          = "lockedTokens/staker/request_unstaking.cdc"
	unstakeAllLockedTokensFilename       = "lockedTokens/staker/unstake_all.cdc"
	withdrawLockedUnstakedTokensFilename = "lockedTokens/staker/withdraw_unstaked_tokens.cdc"
	withdrawLockedRewardedTokensFilename = "lockedTokens/staker/withdraw_rewarded_tokens.cdc"

	// delegator templates
	registerLockedDelegatorFilename               = "lockedTokens/delegator/register_delegator.cdc"
	delegateNewLockedTokensFilename               = "lockedTokens/delegator/delegate_new_locked_tokens.cdc"
	delegateLockedUnstakedTokensFilename          = "lockedTokens/delegator/delegate_locked_unstaked_tokens.cdc"
	delegateLockedRewardedTokensFilename          = "lockedTokens/delegator/delegate_locked_rewarded_tokens.cdc"
	requestUnstakingLockedDelegatedTokensFilename = "lockedTokens/delegator/request_unstaking_locked_delegated_tokens.cdc"
	withdrawLockedUnstakedDelegatedTokensFilename = "lockedTokens/delegator/withdraw_locked_unstaked_delegated_tokens.cdc"
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

func GenerateDepositAccountCreatorScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + depositAccountCreatorCapabilityFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

/************ Custody Provider Transactions ********************/

func GenerateSetupCustodyAccountScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + setupCustodyAccountFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func GenerateCustodyCreateAccountsScript(ftAddr, flowTokenAddr, lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + custodyCreateAccountsFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func GenerateCustodyCreateOnlySharedAccountScript(ftAddr, flowTokenAddr, lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + custodyCreateOnlySharedAccountFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

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

func GenerateGetLockedAccountAddressScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + getLockedAccountAddressFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func GenerateGetLockedAccountBalanceScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + getBalanceFilename)

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

// GenerateStakeLockedUnstakedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateStakeLockedUnstakedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeLockedUnstakedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateStakeLockedRewardedTokensScript creates a script that stakes
// unstaked tokens.
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

// GenerateWithdrawLockedUnstakedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawLockedUnstakedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedUnstakedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateWithdrawLockedRewardedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
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

// GenerateDelegateLockedUnstakedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateDelegateLockedUnstakedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + delegateLockedUnstakedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateDelegateLockedRewardedTokensScript creates a script that stakes
// unstaked tokens.
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

// GenerateWithdrawDelegatorLockedUnstakedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawDelegatorLockedUnstakedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedUnstakedDelegatedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// GenerateWithdrawDelegatorLockedRewardedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawDelegatorLockedRewardedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedRewardedDelegatedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}
