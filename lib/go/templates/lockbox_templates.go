package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// admin templates
	deployLockedTokensFilename              = "lockedTokens/admin/admin_deploy_contract.cdc"
	createLockedAccountsFilename            = "lockedTokens/admin/admin_create_shared_accounts.cdc"
	checkSharedRegistrationFilename         = "lockedTokens/admin/check_shared_registration.cdc"
	checkMainRegistrationFilename           = "lockedTokens/admin/check_main_registration.cdc"
	depositLockedTokensFilename             = "lockedTokens/admin/deposit_locked_tokens.cdc"
	increaseUnlockLimitFilename             = "lockedTokens/admin/unlock_tokens.cdc"
	depositAccountCreatorCapabilityFilename = "lockedTokens/admin/admin_deposit_account_creator.cdc"

	// Custody Provider / Wallet provider Account creation templates
	setupCustodyAccountFilename                  = "lockedTokens/admin/custody_setup_account_creator.cdc"
	custodyCreateAccountsFilename                = "lockedTokens/admin/custody_create_shared_accounts.cdc"
	custodyCreateOnlySharedAccountFilename       = "lockedTokens/admin/custody_create_only_shared_account.cdc"
	custodyCreateAccountWothLeaseAccountFilename = "lockedTokens/admin/custody_create_account_with_lease_account.cdc"

	// user templates
	withdrawTokensFilename          = "lockedTokens/user/withdraw_tokens.cdc"
	depositTokensFilename           = "lockedTokens/user/deposit_tokens.cdc"
	getLockedAccountAddressFilename = "lockedTokens/user/get_locked_account_address.cdc"
	getLockedAccountBalanceFilename = "lockedTokens/user/get_locked_account_balance.cdc"
	getUnlockLimitFilename          = "lockedTokens/user/get_unlock_limit.cdc"

	// staker templates
	registerLockedNodeFilename           = "lockedTokens/staker/register_node.cdc"
	getNodeIDFilename                    = "lockedTokens/staker/get_node_id.cdc"
	stakeNewLockedTokensFilename         = "lockedTokens/staker/stake_new_tokens.cdc"
	stakeLockedUnstakedTokensFilename    = "lockedTokens/staker/stake_unstaked_tokens.cdc"
	stakeLockedRewardedTokensFilename    = "lockedTokens/staker/stake_rewarded_tokens.cdc"
	unstakeLockedTokensFilename          = "lockedTokens/staker/request_unstaking.cdc"
	unstakeAllLockedTokensFilename       = "lockedTokens/staker/unstake_all.cdc"
	withdrawLockedUnstakedTokensFilename = "lockedTokens/staker/withdraw_unstaked_tokens.cdc"
	withdrawLockedRewardedTokensFilename = "lockedTokens/staker/withdraw_rewarded_tokens.cdc"

	// delegator templates
	registerLockedDelegatorFilename               = "lockedTokens/delegator/register_delegator.cdc"
	getDelegatorIDFilename                        = "lockedTokens/delegator/get_delegator_id.cdc"
	getDelegatorNodeIDFilename                    = "lockedTokens/delegator/get_delegator_node_id.cdc"
	delegateNewLockedTokensFilename               = "lockedTokens/delegator/delegate_new_tokens.cdc"
	delegateLockedUnstakedTokensFilename          = "lockedTokens/delegator/delegate_unstaked_tokens.cdc"
	delegateLockedRewardedTokensFilename          = "lockedTokens/delegator/delegate_rewarded_tokens.cdc"
	requestUnstakingLockedDelegatedTokensFilename = "lockedTokens/delegator/request_unstaking.cdc"
	withdrawLockedUnstakedDelegatedTokensFilename = "lockedTokens/delegator/withdraw_unstaked_tokens.cdc"
	withdrawLockedRewardedDelegatedTokensFilename = "lockedTokens/delegator/withdraw_rewarded_tokens.cdc"
)

/************ LockedTokens Admin Transactions ****************/

func GenerateDeployLockedTokens() []byte {
	return assets.MustAsset(filePath + deployLockedTokensFilename)
}

func GenerateCreateSharedAccountScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + createLockedAccountsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCheckSharedRegistrationScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + checkSharedRegistrationFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCheckMainRegistrationScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + checkMainRegistrationFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDepositLockedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + depositLockedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateIncreaseUnlockLimitScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + increaseUnlockLimitFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDepositAccountCreatorScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + depositAccountCreatorCapabilityFilename)

	return []byte(replaceAddresses(code, env))
}

/************ Custody Provider Transactions ********************/

func GenerateSetupCustodyAccountScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + setupCustodyAccountFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCustodyCreateAccountsScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + custodyCreateAccountsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCustodyCreateOnlySharedAccountScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + custodyCreateOnlySharedAccountFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCustodyCreateAccountWithLeaseAccountScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + custodyCreateAccountWothLeaseAccountFilename)

	return []byte(replaceAddresses(code, env))
}

/************ User Transactions ********************/

func GenerateWithdrawTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + withdrawTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDepositTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + depositTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetLockedAccountAddressScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getLockedAccountAddressFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetLockedAccountBalanceScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getLockedAccountBalanceFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetUnlockLimitScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getUnlockLimitFilename)

	return []byte(replaceAddresses(code, env))
}

/************ Node Staker Transactions ******************/

// CreateLockedNodeScript creates a script that creates a new
// node request with locked tokens.
func GenerateRegisterLockedNodeScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + registerLockedNodeFilename)

	return []byte(replaceAddresses(code, env))
}

// StakeNewLockedTokensScript creates a script that stakes new
// locked tokens.
func GenerateStakeNewLockedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + stakeNewLockedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// StakeLockedUnstakedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateStakeLockedUnstakedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + stakeLockedUnstakedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// StakeLockedRewardedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateStakeLockedRewardedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + stakeLockedRewardedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// UnstakeLockedTokensScript creates a script that unstakes
// locked tokens.
func GenerateUnstakeLockedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + unstakeLockedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// UnstakeAllLockedTokensScript creates a script that unstakes
// all locked tokens.
func GenerateUnstakeAllLockedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + unstakeAllLockedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// WithdrawLockedUnstakedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawLockedUnstakedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedUnstakedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// WithdrawLockedRewardedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawLockedRewardedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedRewardedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetNodeIDScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getNodeIDFilename)

	return []byte(replaceAddresses(code, env))
}

/******************** Delegator Transactions ****************************/

// CreateLockedDelegatorScript creates a script that creates a new
// node request with locked tokens.
func GenerateCreateLockedDelegatorScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + registerLockedDelegatorFilename)

	return []byte(replaceAddresses(code, env))
}

// DelegateNewLockedTokensScript creates a script that stakes new
// locked tokens.
func GenerateDelegateNewLockedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + delegateNewLockedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// DelegateLockedUnstakedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateDelegateLockedUnstakedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + delegateLockedUnstakedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// DelegateLockedRewardedTokensScript creates a script that stakes
// unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateDelegateLockedRewardedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + delegateLockedRewardedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// UnDelegateLockedTokensScript creates a script that unstakes
// locked tokens.
func GenerateUnDelegateLockedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + requestUnstakingLockedDelegatedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// WithdrawDelegatorLockedUnstakedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawDelegatorLockedUnstakedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedUnstakedDelegatedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// WithdrawDelegatorLockedRewardedTokensScript creates a script that requests
// a withdrawal of unstaked tokens.
// The unusual name is to avoid a clash with idtables_staking_templates.go .
func GenerateWithdrawDelegatorLockedRewardedTokensScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + withdrawLockedRewardedDelegatedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorIDScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getDelegatorIDFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorNodeIDScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getDelegatorNodeIDFilename)

	return []byte(replaceAddresses(code, env))
}
