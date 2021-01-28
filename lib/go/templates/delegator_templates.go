package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	createDelegationFilename       = "idTableStaking/delegation/del_create_delegation.cdc"
	delegatorAddCapabilityFilename = "idTableStaking/delegation/delegator_add_capability.cdc"

	delegatorRegisterFilename         = "idTableStaking/delegation/register_delegator.cdc"
	delegatorStakeNewFilename         = "idTableStaking/delegation/del_stake_new_tokens.cdc"
	delegatorStakeUnstakedFilename    = "idTableStaking/delegation/del_stake_unstaked.cdc"
	delegatorStakeRewardedFilename    = "idTableStaking/delegation/del_stake_rewarded.cdc"
	delegatorRequestUnstakeFilename   = "idTableStaking/delegation/del_request_unstaking.cdc"
	delegatorWithdrawRewardsFilename  = "idTableStaking/delegation/del_withdraw_reward_tokens.cdc"
	delegatorWithdrawUnstakedFilename = "idTableStaking/delegation/del_withdraw_unstaked_tokens.cdc"

	getDelegatorInfoFilename             = "idTableStaking/delegation/get_delegator_info.cdc"
	getDelegatorInfoFromAddressFilename  = "idTableStaking/delegation/get_delegator_info_from_address.cdc"
	getDelegatorCommittedFilename        = "idTableStaking/delegation/get_delegator_committed.cdc"
	getDelegatorStakedFilename           = "idTableStaking/delegation/get_delegator_staked.cdc"
	getDelegatorUnstakingRequestFilename = "idTableStaking/delegation/get_delegator_unstaking_request.cdc"
	getDelegatorUnstakingFilename        = "idTableStaking/delegation/get_delegator_unstaking.cdc"
	getDelegatorUnstakedFilename         = "idTableStaking/delegation/get_delegator_unstaked.cdc"
	getDelegatorRewardedFilename         = "idTableStaking/delegation/get_delegator_rewarded.cdc"
	getDelegatorRequestFilename          = "idTableStaking/delegation/get_delegator_request.cdc"

	registerManyDelegatorsFilename = "idTableStaking/delegation/register_many_delegators.cdc"
)

func GenerateCreateDelegationScript(env Environment) []byte {
	code := assets.MustAssetString(createDelegationFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateRegisterDelegatorScript(env Environment) []byte {
	code := assets.MustAssetString(delegatorRegisterFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDelegatorStakeNewScript(env Environment) []byte {
	code := assets.MustAssetString(delegatorStakeNewFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDelegatorStakeUnstakedScript(env Environment) []byte {
	code := assets.MustAssetString(delegatorStakeUnstakedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDelegatorStakeRewardedScript(env Environment) []byte {
	code := assets.MustAssetString(delegatorStakeRewardedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDelegatorRequestUnstakeScript(env Environment) []byte {
	code := assets.MustAssetString(delegatorRequestUnstakeFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDelegatorWithdrawUnstakedScript(env Environment) []byte {
	code := assets.MustAssetString(delegatorWithdrawUnstakedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDelegatorWithdrawRewardsScript(env Environment) []byte {
	code := assets.MustAssetString(delegatorWithdrawRewardsFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateAddPublicDelegatorCapabilityScript(env Environment) []byte {
	code := assets.MustAssetString(delegatorAddCapabilityFilename)

	return []byte(replaceAddresses(code, env))
}

// Scripts

func GenerateGetDelegatorInfoScript(env Environment) []byte {
	code := assets.MustAssetString(getDelegatorInfoFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorInfoFromAddressScript(env Environment) []byte {
	code := assets.MustAssetString(getDelegatorInfoFromAddressFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorCommittedScript(env Environment) []byte {
	code := assets.MustAssetString(getDelegatorCommittedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorStakedScript(env Environment) []byte {
	code := assets.MustAssetString(getDelegatorStakedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorUnstakingRequestScript(env Environment) []byte {
	code := assets.MustAssetString(getDelegatorUnstakingRequestFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorUnstakingScript(env Environment) []byte {
	code := assets.MustAssetString(getDelegatorUnstakingFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorUnstakedScript(env Environment) []byte {
	code := assets.MustAssetString(getDelegatorUnstakedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorRewardsScript(env Environment) []byte {
	code := assets.MustAssetString(getDelegatorRewardedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorRequestScript(env Environment) []byte {
	code := assets.MustAssetString(getDelegatorRequestFilename)

	return []byte(replaceAddresses(code, env))
}

// Only for testing

func GenerateRegisterManyDelegatorsScript(env Environment) []byte {
	code := assets.MustAssetString(registerManyDelegatorsFilename)

	return []byte(replaceAddresses(code, env))
}
