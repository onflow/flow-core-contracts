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

func CreateDelegationScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + createDelegationFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func RegisterDelegatorScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorRegisterFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func DelegatorStakeNewScript(ftAddress, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorStakeNewFilename)

	return []byte(ReplaceAddresses(code, ftAddress, flowAddr, idTableAddr))
}

func DelegatorStakeUnstakedScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorStakeUnstakedFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func DelegatorStakeRewardedScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorStakeRewardedFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func DelegatorRequestUnstakeScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorRequestUnstakeFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func DelegatorWithdrawUnstakedScript(ftAddress, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorWithdrawUnstakedFilename)

	return []byte(ReplaceAddresses(code, ftAddress, flowAddr, idTableAddr))
}

func DelegatorWithdrawRewardsScript(ftAddress, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorWithdrawRewardsFilename)

	return []byte(ReplaceAddresses(code, ftAddress, flowAddr, idTableAddr))
}

/// Scripts

func GetDelegatorCommittedScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorCommittedFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GetDelegatorStakedScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorStakedFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GetDelegatorUnstakingScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorUnstakingFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GetDelegatorUnstakedScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorUnstakedFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GetDelegatorRewardsScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorRewardedFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GetDelegatorRequestScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorRequestFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}
