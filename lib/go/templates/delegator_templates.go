package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	delegatorRegisterFilename         = "idTableStaking/delegation/del_register_delegator.cdc"
	delegatorStakeNewFilename         = "idTableStaking/delegation/del_stake_new_tokens.cdc"
	delegatorStakeUnlockedFilename    = "idTableStaking/delegation/del_stake_unlocked.cdc"
	delegatorStakeRewardedFilename    = "idTableStaking/delegation/del_stake_rewarded.cdc"
	delegatorRequestUnstakeFilename   = "idTableStaking/delegation/del_request_unstaking.cdc"
	delegatorWithdrawRewardsFilename  = "idTableStaking/delegation/del_withdraw_reward_tokens.cdc"
	delegatorWithdrawUnlockedFilename = "idTableStaking/delegation/del_withdraw_unlocked_tokens.cdc"

	getDelegatorCommittedFilename = "idTableStaking/delegation/get_delegator_committed.cdc"
	getDelegatorStakedFilename    = "idTableStaking/delegation/get_delegator_staked.cdc"
	getDelegatorUnstakedFilename  = "idTableStaking/delegation/get_delegator_unstaked.cdc"
	getDelegatorUnlockedFilename  = "idTableStaking/delegation/get_delegator_unlocked.cdc"
	getDelegatorRewardedFilename  = "idTableStaking/delegation/get_delegator_rewarded.cdc"
	getDelegatorRequestFilename   = "idTableStaking/delegation/get_delegator_request.cdc"
)

func GenerateRegisterDelegatorScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorRegisterFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GenerateDelegatorStakeNewScript(ftAddress, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorStakeNewFilename)

	return []byte(ReplaceAddresses(code, ftAddress, flowAddr, idTableAddr))
}

func GenerateDelegatorStakeUnlockedScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorStakeUnlockedFilename)

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

func GenerateDelegatorWithdrawUnlockedScript(ftAddress, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + delegatorWithdrawUnlockedFilename)

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

func GenerateGetDelegatorUnstakedScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorUnstakedFilename)

	return []byte(ReplaceAddresses(code, "", "", idTableAddr))
}

func GenerateGetDelegatorUnlockedScript(idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + getDelegatorUnlockedFilename)

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
