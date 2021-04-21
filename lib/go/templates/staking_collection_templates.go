package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// admin templates
	deployStakingCollectionFilename = "stakingCollection/deploy_collection_contract.cdc"

	// setup template
	collectionSetupFilename = "stakingCollection/setup_staking_collection.cdc"

	// user templates
	collectionAddDelegatorFilename           = "stakingCollection/add_delegator.cdc"
	collectionAddNodeFilename                = "stakingCollection/add_node.cdc"
	collectionRegisterDelegatorFilename      = "stakingCollection/register_delegator.cdc"
	collectionRegisterNodeFilename           = "stakingCollection/register_node.cdc"
	collectionRequestUnstakingFilename       = "stakingCollection/request_unstaking.cdc"
	collectionStakeNewTokensFilename         = "stakingCollection/stake_new_tokens.cdc"
	collectionStakeRewardedTokensFilename    = "stakingCollection/stake_rewarded_tokens.cdc"
	collectionStakeUnstakedTokensFilename    = "stakingCollection/stake_unstaked_tokens.cdc"
	collectionUnstakeAllFilename             = "stakingCollection/unstake_all.cdc"
	collectionWithdrawRewardedTokensFilename = "stakingCollection/withdraw_rewarded_tokens.cdc"
	collectionWithdrawUnstakedTokensFilename = "stakingCollection/withdraw_unstaked_tokens.cdc"
	collectionCloseStakeFilename			 = "stakingCollection/close_stake.cdc"
	collectionTransferNodeFilename			 = "stakingCollection/transfer_node.cdc"
	collectionTransferDelegatorFilename	     = "stakingCollection/transfer_delegator.cdc"

	// scripts
	collectionGetDoesStakeExistFilename     			= "stakingCollection/scripts/get_does_stake_exist.cdc"
	collectionGetNodeIDs                    			= "stakingCollection/scripts/get_node_ids.cdc"
	collectionGetDelegatorIDs               			= "stakingCollection/scripts/get_delegator_ids.cdc"
	collectionGetAllNodeInfo                			= "stakingCollection/scripts/get_all_node_info.cdc"
	collectionGetAllDelegatorInfo           			= "stakingCollection/scripts/get_all_delegator_info.cdc"
	collectionGetLockedTokensUsedFilename   			= "stakingCollection/scripts/get_locked_tokens_used.cdc"
	collectionGetUnlockedTokensUsedFilename 			= "stakingCollection/scripts/get_unlocked_tokens_used.cdc"
	collectionDoesAccountHaveStakingCollectionFilename  = "stakingCollection/scripts/does_account_have_staking_collection.cdc"

	// tests
	getCollectionTokensFilename     = "stakingCollection/test/get_tokens.cdc"
	depositCollectionTokensFilename = "stakingCollection/test/deposit_tokens.cdc"
)

func GenerateDeployStakingCollectionScript() []byte {
	return assets.MustAsset(deployStakingCollectionFilename)
}

// User Templates

func GenerateCollectionSetup(env Environment) []byte {
	code := assets.MustAssetString(collectionSetupFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionAddDelegator(env Environment) []byte {
	code := assets.MustAssetString(collectionAddDelegatorFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionAddNode(env Environment) []byte {
	code := assets.MustAssetString(collectionAddNodeFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionRegisterDelegator(env Environment) []byte {
	code := assets.MustAssetString(collectionRegisterDelegatorFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionRegisterNode(env Environment) []byte {
	code := assets.MustAssetString(collectionRegisterNodeFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionRequestUnstaking(env Environment) []byte {
	code := assets.MustAssetString(collectionRequestUnstakingFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionStakeNewTokens(env Environment) []byte {
	code := assets.MustAssetString(collectionStakeNewTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionStakeRewardedTokens(env Environment) []byte {
	code := assets.MustAssetString(collectionStakeRewardedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionStakeUnstakedTokens(env Environment) []byte {
	code := assets.MustAssetString(collectionStakeUnstakedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionUnstakeAll(env Environment) []byte {
	code := assets.MustAssetString(collectionUnstakeAllFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionWithdrawRewardedTokens(env Environment) []byte {
	code := assets.MustAssetString(collectionWithdrawRewardedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionWithdrawUnstakedTokens(env Environment) []byte {
	code := assets.MustAssetString(collectionWithdrawUnstakedTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionCloseStake(env Environment) []byte {
	code := assets.MustAssetString(collectionCloseStakeFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionTransferNode(env Environment) []byte {
	code := assets.MustAssetString(collectionTransferNodeFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionTransferDelegator(env Environment) []byte {
	code := assets.MustAssetString(collectionTransferDelegatorFilename)

	return []byte(replaceAddresses(code, env))
}

// Script templates

func GenerateCollectionGetDoesStakeExistScript(env Environment) []byte {
	code := assets.MustAssetString(collectionGetDoesStakeExistFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionGetNodeIDsScript(env Environment) []byte {
	code := assets.MustAssetString(collectionGetNodeIDs)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionGetDelegatorIDsScript(env Environment) []byte {
	code := assets.MustAssetString(collectionGetDelegatorIDs)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionGetAllNodeInfoScript(env Environment) []byte {
	code := assets.MustAssetString(collectionGetAllNodeInfo)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionGetAllDelegatorInfoScript(env Environment) []byte {
	code := assets.MustAssetString(collectionGetAllDelegatorInfo)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionGetUnlockedTokensUsedScript(env Environment) []byte {
	code := assets.MustAssetString(collectionGetUnlockedTokensUsedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionGetLockedTokensUsedScript(env Environment) []byte {
	code := assets.MustAssetString(collectionGetLockedTokensUsedFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionDoesAccountHaveStakingCollection(env Environment) []byte {
	code := assets.MustAssetString(collectionDoesAccountHaveStakingCollectionFilename)

	return []byte(replaceAddresses(code, env))
}

// Test Templates

func GenerateCollectionGetTokensScript(env Environment) []byte {
	code := assets.MustAssetString(getCollectionTokensFilename)

	return []byte(replaceAddresses(code, env))
}

func GenerateCollectionDepositTokensScript(env Environment) []byte {
	code := assets.MustAssetString(depositCollectionTokensFilename)

	return []byte(replaceAddresses(code, env))
}
