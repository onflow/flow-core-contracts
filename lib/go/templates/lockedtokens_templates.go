package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// admin templates
	deployLockedTokensFilename                     = "lockedTokens/admin/admin_deploy_contract.cdc"
	createLockedAccountsFilename                   = "lockedTokens/admin/admin_create_shared_accounts.cdc"
	checkSharedRegistrationFilename                = "lockedTokens/admin/check_shared_registration.cdc"
	checkMainRegistrationFilename                  = "lockedTokens/admin/check_main_registration.cdc"
	depositLockedTokensFilename                    = "lockedTokens/admin/deposit_locked_tokens.cdc"
	increaseUnlockLimitFilename                    = "lockedTokens/admin/unlock_tokens.cdc"
	increaseUnlockLimitForMultipleAccountsFilename = "lockedTokens/admin/unlock_tokens_for_multiple_accounts.cdc"
	depositAccountCreatorCapabilityFilename        = "lockedTokens/admin/admin_deposit_account_creator.cdc"
	removeDelegatorFilename                        = "lockedTokens/admin/admin_remove_delegator.cdc"
	getBadAccountsFilename                         = "lockedTokens/admin/get_unlocking_bad_accounts.cdc"

	// Custody Provider / Wallet provider Account creation templates
	setupCustodyAccountFilename                  = "lockedTokens/admin/custody_setup_account_creator.cdc"
	custodyCreateAccountsFilename                = "lockedTokens/admin/custody_create_shared_accounts.cdc"
	custodyCreateOnlySharedAccountFilename       = "lockedTokens/admin/custody_create_only_shared_account.cdc"
	custodyCreateAccountWithLeaseAccountFilename = "lockedTokens/admin/custody_create_account_with_lease_account.cdc"
	custodyCreateOnlyLeaseAccountFilename        = "lockedTokens/admin/custody_create_only_lease_account.cdc"

	// user templates
	withdrawTokensFilename          = "lockedTokens/user/withdraw_tokens.cdc"
	depositTokensFilename           = "lockedTokens/user/deposit_tokens.cdc"
	getLockedAccountAddressFilename = "lockedTokens/user/get_locked_account_address.cdc"
	getLockedAccountBalanceFilename = "lockedTokens/user/get_locked_account_balance.cdc"
	getUnlockLimitFilename          = "lockedTokens/user/get_unlock_limit.cdc"
	getTotalBalanceFilename         = "lockedTokens/user/get_total_balance.cdc"

	// staker templates
	registerLockedNodeFilename                 = "lockedTokens/staker/register_node.cdc"
	getLockedNodeIDFilename                    = "lockedTokens/staker/get_node_id.cdc"
	getLockedStakerInfoFilename                = "lockedTokens/staker/get_staker_info.cdc"
	stakeNewLockedTokensFilename               = "lockedTokens/staker/stake_new_tokens.cdc"
	stakeLockedUnstakedTokensFilename          = "lockedTokens/staker/stake_unstaked_tokens.cdc"
	stakeLockedRewardedTokensFilename          = "lockedTokens/staker/stake_rewarded_tokens.cdc"
	unstakeLockedTokensFilename                = "lockedTokens/staker/request_unstaking.cdc"
	unstakeAllLockedTokensFilename             = "lockedTokens/staker/unstake_all.cdc"
	withdrawLockedUnstakedTokensFilename       = "lockedTokens/staker/withdraw_unstaked_tokens.cdc"
	withdrawLockedRewardedTokensFilename       = "lockedTokens/staker/withdraw_rewarded_tokens.cdc"
	withdrawLockedRewardedTokensLockedFilename = "lockedTokens/staker/withdraw_rewarded_tokens_locked.cdc"
	lockedNodeUpdateNetworkingAddressFilename  = "lockedTokens/staker/update_networking_address.cdc"

	// delegator templates
	registerLockedDelegatorFilename                     = "lockedTokens/delegator/register_delegator.cdc"
	getLockedDelegatorIDFilename                        = "lockedTokens/delegator/get_delegator_id.cdc"
	getLockedDelegatorInfoFilename                      = "lockedTokens/delegator/get_delegator_info.cdc"
	getDelegatorNodeIDFilename                          = "lockedTokens/delegator/get_delegator_node_id.cdc"
	delegateNewLockedTokensFilename                     = "lockedTokens/delegator/delegate_new_tokens.cdc"
	delegateLockedUnstakedTokensFilename                = "lockedTokens/delegator/delegate_unstaked_tokens.cdc"
	delegateLockedRewardedTokensFilename                = "lockedTokens/delegator/delegate_rewarded_tokens.cdc"
	requestUnstakingLockedDelegatedTokensFilename       = "lockedTokens/delegator/request_unstaking.cdc"
	withdrawLockedUnstakedDelegatedTokensFilename       = "lockedTokens/delegator/withdraw_unstaked_tokens.cdc"
	withdrawLockedRewardedDelegatedTokensFilename       = "lockedTokens/delegator/withdraw_rewarded_tokens.cdc"
	withdrawLockedRewardedDelegatedTokensLockedFilename = "lockedTokens/delegator/withdraw_rewarded_tokens_locked.cdc"
)

/************ LockedTokens Admin Transactions ****************/

func GenerateDeployLockedTokens() []byte {
	return assets.MustAsset(deployLockedTokensFilename)
}

func GenerateCreateSharedAccountScript(env Environment) []byte {
	code := assets.MustAssetString(createLockedAccountsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCheckSharedRegistrationScript(env Environment) []byte {
	code := assets.MustAssetString(checkSharedRegistrationFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCheckMainRegistrationScript(env Environment) []byte {
	code := assets.MustAssetString(checkMainRegistrationFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDepositLockedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(depositLockedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateIncreaseUnlockLimitScript(env Environment) []byte {
	code := assets.MustAssetString(increaseUnlockLimitFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateIncreaseUnlockLimitForMultipleAccountsScript(env Environment) []byte {
	code := assets.MustAssetString(increaseUnlockLimitForMultipleAccountsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDepositAccountCreatorScript(env Environment) []byte {
	code := assets.MustAssetString(depositAccountCreatorCapabilityFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateRemoveDelegatorScript(env Environment) []byte {
	code := assets.MustAssetString(removeDelegatorFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetBadAccountsScript(env Environment) []byte {
	code := assets.MustAssetString(getBadAccountsFilename)

	return []byte(replaceAddresses(code, env))
}

/************ Custody Provider Transactions ********************/

func GenerateSetupCustodyAccountScript(env Environment) []byte {
	code := assets.MustAssetString(setupCustodyAccountFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCustodyCreateAccountsScript(env Environment) []byte {
	code := assets.MustAssetString(custodyCreateAccountsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCustodyCreateOnlySharedAccountScript(env Environment) []byte {
	code := assets.MustAssetString(custodyCreateOnlySharedAccountFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCustodyCreateAccountWithLeaseAccountScript(env Environment) []byte {
	code := assets.MustAssetString(custodyCreateAccountWithLeaseAccountFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCustodyCreateOnlyLeaseAccountScript(env Environment) []byte {
	code := assets.MustAssetString(custodyCreateOnlyLeaseAccountFilename)

	return []byte(replaceAddresses(code, env))
}

/************ User Transactions ********************/

func GenerateWithdrawTokensScript(env Environment) []byte {
	code := assets.MustAssetString(withdrawTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDepositTokensScript(env Environment) []byte {
	code := assets.MustAssetString(depositTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetLockedAccountAddressScript(env Environment) []byte {
	code := assets.MustAssetString(getLockedAccountAddressFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetLockedAccountBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(getLockedAccountBalanceFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetUnlockLimitScript(env Environment) []byte {
	code := assets.MustAssetString(getUnlockLimitFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetTotalBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(getTotalBalanceFilename)

	return []byte(replaceAddresses(code, env))
}

/************ Node Staker Transactions ******************/

// CreateLockedNodeScript creates a script that creates a new
// node request with locked tokens.
func GenerateRegisterLockedNodeScript(env Environment) []byte {
	code := assets.MustAssetString(registerLockedNodeFilename)

	return []byte(replaceAddresses(code, env))
}

// StakeNewLockedTokensScript creates a script that stakes new
// locked tokens.
func GenerateStakeNewLockedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(stakeNewLockedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// StakeLockedUnstakedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateStakeLockedUnstakedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(stakeLockedUnstakedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// StakeLockedRewardedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateStakeLockedRewardedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(stakeLockedRewardedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// UnstakeLockedTokensScript creates a script that unstakes
// locked tokens.
func GenerateUnstakeLockedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(unstakeLockedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// UnstakeAllLockedTokensScript creates a script that unstakes
// all locked tokens.
func GenerateUnstakeAllLockedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(unstakeAllLockedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// WithdrawLockedUnstakedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawLockedUnstakedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(withdrawLockedUnstakedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// WithdrawLockedRewardedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawLockedRewardedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(withdrawLockedRewardedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// Change the networking address of a locked node
func GenerateLockedNodeUpdateNetworkingAddressScript(env Environment) []byte {
	code := assets.MustAssetString(lockedNodeUpdateNetworkingAddressFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateWithdrawLockedRewardedTokensToLockedAccountScript(env Environment) []byte {
	code := assets.MustAssetString(withdrawLockedRewardedTokensLockedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetNodeIDScript(env Environment) []byte {
	code := assets.MustAssetString(getLockedNodeIDFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetStakerInfoScript creats a script that returns an optional
// FlowIDTableStaking.NodeInfo? object that is associated with an account
// that is staking locked tokens
func GenerateGetLockedStakerInfoScript(env Environment) []byte {
	code := assets.MustAssetString(getLockedStakerInfoFilename)

	return []byte(replaceAddresses(code, env))
}

/******************** Delegator Transactions ****************************/

// CreateLockedDelegatorScript creates a script that creates a new
// node request with locked tokens.
func GenerateCreateLockedDelegatorScript(env Environment) []byte {
	code := assets.MustAssetString(registerLockedDelegatorFilename)

	return []byte(replaceAddresses(code, env))
}

// DelegateNewLockedTokensScript creates a script that stakes new
// locked tokens.
func GenerateDelegateNewLockedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(delegateNewLockedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// DelegateLockedUnstakedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateDelegateLockedUnstakedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(delegateLockedUnstakedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// DelegateLockedRewardedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateDelegateLockedRewardedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(delegateLockedRewardedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// UnDelegateLockedTokensScript creates a script that unstakes
// locked tokens.
func GenerateUnDelegateLockedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(requestUnstakingLockedDelegatedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// WithdrawDelegatorLockedUnstakedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawDelegatorLockedUnstakedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(withdrawLockedUnstakedDelegatedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// WithdrawDelegatorLockedRewardedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawDelegatorLockedRewardedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(withdrawLockedRewardedDelegatedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateWithdrawDelegatorLockedRewardedTokensToLockedAccountScript(env Environment) []byte {
	code := assets.MustAssetString(withdrawLockedRewardedDelegatedTokensLockedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorIDScript(env Environment) []byte {
	code := assets.MustAssetString(getLockedDelegatorIDFilename)

	return []byte(replaceAddresses(code, env))
}

// GenerateGetDelegatorInfoScript creates a script that returns an optional
// FlowIDTableStaking.DelegatorInfo object that is associated with an account
// that is delegating locked tokens
func GenerateGetLockedDelegatorInfoScript(env Environment) []byte {
	code := assets.MustAssetString(getLockedDelegatorInfoFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorNodeIDScript(env Environment) []byte {
	code := assets.MustAssetString(getDelegatorNodeIDFilename)

	return []byte(replaceAddresses(code, env))
}
