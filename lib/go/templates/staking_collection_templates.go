package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// admin templates
	deployStakingCollectionFilename = "stakingCollection/deploy_collection_contract.cdc"

	// user templates
	collectionStakeNewTokensFilename = "stakingCollection/stake_new_tokens.cdc"
)

func GenerateDeployStakingCollectionScript() []byte {
	return assets.MustAsset(deployStakingCollectionFilename)
}

// User Templates

func GenerateCollectionStakeNewTokens(env Environment) []byte {

	code := assets.MustAssetString(collectionStakeNewTokensFilename)

	return []byte(replaceAddresses(code, env))
}

// script templates
