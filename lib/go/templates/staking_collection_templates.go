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
	collectionAddDelegatorFilename = "stakingCollection/add_delegator.cdc"
	collectionAddNodeFilename = "stakingCollection/add_node.cdc"
	collectionRegisterDelegatorFilename = "stakingCollection/register_delegator.cdc"
	collectionRegisterNodeFilename = "stakingCollection/register_node.cdc"
	collectionRequestUnstakingFilename = "stakingCollection/request_unstaking.cdc"
	collectionStakeNewTokensFilename = "stakingCollection/stake_new_tokens.cdc"
	collectionStakeRewardedTokensFilename = "stakingCollection/stake_rewarded_tokens.cdc"
	collectionStakeUnstakedTokensFilename = "stakingCollection/stake_unstaked_tokens.cdc"
	collectionUnstakeAllFilename = "stakingCollection/unstake_all.cdc"
	collectionWithdrawRewardedTokensFilename = "stakingCollection/withdraw_rewarded_tokens.cdc"
	collectionWithdrawUnstakedTokensFilename = "stakingCollection/withdraw_unstaked_tokens.cdc"
)

func GenerateDeployStakingCollectionScript() []byte {
	return assets.MustAsset(deployStakingCollectionFilename)
}

// User Templates

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

// script templates
