package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	createDelegationFilename = "idTableStaking/delegation/del_create_delegation.cdc"

	delegatorRegisterFilename         = "idTableStaking/delegation/del_register_delegator.cdc"
	delegatorStakeNewFilename         = "idTableStaking/delegation/del_stake_new_tokens.cdc"
	delegatorStakeUnstakedFilename    = "idTableStaking/delegation/del_stake_unstaked.cdc"
	delegatorStakeRewardedFilename    = "idTableStaking/delegation/del_stake_rewarded.cdc"
	delegatorRequestUnstakeFilename   = "idTableStaking/delegation/del_request_unstaking.cdc"
	delegatorWithdrawRewardsFilename  = "idTableStaking/delegation/del_withdraw_reward_tokens.cdc"
	delegatorWithdrawUnstakedFilename = "idTableStaking/delegation/del_withdraw_unstaked_tokens.cdc"

	getDelegatorCommittedFilename = "idTableStaking/delegation/get_delegator_committed.cdc"
	getDelegatorStakedFilename    = "idTableStaking/delegation/get_delegator_staked.cdc"
	getDelegatorUnstakingFilename = "idTableStaking/delegation/get_delegator_unstaking.cdc"
	getDelegatorUnstakedFilename  = "idTableStaking/delegation/get_delegator_unstaked.cdc"
	getDelegatorRewardedFilename  = "idTableStaking/delegation/get_delegator_rewarded.cdc"
	getDelegatorRequestFilename   = "idTableStaking/delegation/get_delegator_request.cdc"
)

func GenerateCreateDelegationScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + createDelegationFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateRegisterDelegatorScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + delegatorRegisterFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDelegatorStakeNewScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + delegatorStakeNewFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDelegatorStakeUnstakedScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + delegatorStakeUnstakedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDelegatorStakeRewardedScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + delegatorStakeRewardedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDelegatorRequestUnstakeScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + delegatorRequestUnstakeFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDelegatorWithdrawUnstakedScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + delegatorWithdrawUnstakedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateDelegatorWithdrawRewardsScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + delegatorWithdrawRewardsFilename)

	return []byte(replaceAddresses(code, env))
}

// Scripts

func GenerateGetDelegatorCommittedScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getDelegatorCommittedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorStakedScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getDelegatorStakedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorUnstakingScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getDelegatorUnstakingFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorUnstakedScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getDelegatorUnstakedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorRewardsScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getDelegatorRewardedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateGetDelegatorRequestScript(env Environment) []byte {
	code := assets.MustAssetString(filePath + getDelegatorRequestFilename)

	return []byte(replaceAddresses(code, env))
}
