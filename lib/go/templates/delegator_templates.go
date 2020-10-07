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

func GenerateCreateDelegationScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + createDelegationFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GenerateRegisterDelegatorScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorRegisterFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GenerateDelegatorStakeNewScript(ftAddress, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorStakeNewFilename)

	return []byte(ReplaceAddresses(code, ftAddress, flowAddr, idTableAddr))
}

func GenerateDelegatorStakeUnstakedScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorStakeUnstakedFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GenerateDelegatorStakeRewardedScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorStakeRewardedFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GenerateDelegatorRequestUnstakeScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorRequestUnstakeFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GenerateDelegatorWithdrawUnstakedScript(ftAddress, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorWithdrawUnstakedFilename)

	return []byte(ReplaceAddresses(code, ftAddress, flowAddr, idTableAddr))
}

func GenerateDelegatorWithdrawRewardsScript(ftAddress, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorWithdrawRewardsFilename)

	return []byte(ReplaceAddresses(code, ftAddress, flowAddr, idTableAddr))
}

/// Scripts

func GenerateGetDelegatorCommittedScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorCommittedFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GenerateGetDelegatorStakedScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorStakedFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GenerateGetDelegatorUnstakingScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorUnstakingFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GenerateGetDelegatorUnstakedScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorUnstakedFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GenerateGetDelegatorRewardsScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorRewardedFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GenerateGetDelegatorRequestScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorRequestFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}
