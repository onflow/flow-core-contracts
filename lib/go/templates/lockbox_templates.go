package templates

import (
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
	withdrawTokensFilename          = "lockedTokens/user/withdraw_tokens.cdc"
	depositTokensFilename           = "lockedTokens/user/deposit_tokens.cdc"
	getLockedAccountAddressFilename = "lockedTokens/user/get_locked_account_address.cdc"
	getLockedAccountBalanceFilename = "lockedTokens/user/get_locked_account_balance.cdc"
	getUnlockLimitFilename          = "lockedTokens/user/get_unlock_limit.cdc"

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
)

/************ LockedTokens Admin Transactions ****************/

func CreateAdminCollectionScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + createAdminCollectionFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func CreateSharedAccountScript(ftAddr, flowTokenAddr, lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + createLockedAccountsFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func DepositLockedTokensScript(ftAddr, flowTokenAddr, lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + depositLockedTokensFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func IncreaseUnlockLimitScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + increaseUnlockLimitFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func DepositAccountCreatorScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + depositAccountCreatorCapabilityFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

/************ Custody Provider Transactions ********************/

func SetupCustodyAccountScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + setupCustodyAccountFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func CustodyCreateAccountsScript(ftAddr, flowTokenAddr, lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + custodyCreateAccountsFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func CustodyCreateOnlySharedAccountScript(ftAddr, flowTokenAddr, lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + custodyCreateOnlySharedAccountFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

/************ User Transactions ********************/

func WithdrawTokensScript(ftAddr, flowTokenAddr, lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawTokensFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func DepositTokensScript(ftAddr, flowTokenAddr, lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + depositTokensFilename)

	code = ReplaceAddresses(code, ftAddr, flowTokenAddr, "")

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func GetLockedAccountAddressScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + getLockedAccountAddressFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func GetLockedAccountBalanceScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + getLockedAccountBalanceFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

func GetUnlockLimitScript(lockedTokensAddr string) []byte {
	code := assets.MustAssetString(filePath + getUnlockLimitFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(code)
}

/************ Node Staker Transactions ******************/

// CreateLockedNodeScript creates a script that creates a new
// node request with locked tokens.
func CreateLockedNodeScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + createLockedNodeFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// StakeNewLockedTokensScript creates a script that stakes new
// locked tokens.
func StakeNewLockedTokensScript(
	fungibleTokenAddr,
	flowTokenAddr,
	lockedTokensAddr,
	proxyAddr string,
) []byte {
	code := assets.MustAssetString(filePath + stakeNewLockedTokensFilename)

	code = ReplaceAddresses(code, fungibleTokenAddr, flowTokenAddr, "")
	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// StakeLockedUnstakedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func StakeLockedUnstakedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeLockedUnstakedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// StakeLockedRewardedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func StakeLockedRewardedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + stakeLockedRewardedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// UnstakeLockedTokensScript creates a script that unstakes
// locked tokens.
func UnstakeLockedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + unstakeLockedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// UnstakeAllLockedTokensScript creates a script that unstakes
// all locked tokens.
func UnstakeAllLockedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + unstakeAllLockedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// WithdrawLockedUnstakedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func WithdrawLockedUnstakedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedUnstakedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// WithdrawLockedRewardedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func WithdrawLockedRewardedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedRewardedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

/******************** Delegator Transactions ****************************/

// CreateLockedDelegatorScript creates a script that creates a new
// node request with locked tokens.
func CreateLockedDelegatorScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + registerLockedDelegatorFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// DelegateNewLockedTokensScript creates a script that stakes new
// locked tokens.
func DelegateNewLockedTokensScript(
	fungibleTokenAddr,
	flowTokenAddr,
	lockedTokensAddr,
	proxyAddr string,
) []byte {
	code := assets.MustAssetString(filePath + delegateNewLockedTokensFilename)

	code = ReplaceAddresses(code, fungibleTokenAddr, flowTokenAddr, "")
	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// DelegateLockedUnstakedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func DelegateLockedUnstakedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + delegateLockedUnstakedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// DelegateLockedRewardedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func DelegateLockedRewardedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + delegateLockedRewardedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// UnDelegateLockedTokensScript creates a script that unstakes
// locked tokens.
func UnDelegateLockedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + requestUnstakingLockedDelegatedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// WithdrawDelegatorLockedUnstakedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func WithdrawDelegatorLockedUnstakedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedUnstakedDelegatedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}

// WithdrawDelegatorLockedRewardedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func WithdrawDelegatorLockedRewardedTokensScript(lockedTokensAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedRewardedDelegatedTokensFilename)

	code = ReplaceLockedTokensAddress(code, lockedTokensAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}
