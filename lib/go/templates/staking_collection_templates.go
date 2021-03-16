package templates

import (
	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// admin templates
	deployStakingCollectionFilename = "stakingCollection/deploy_collection_contract.cdc"
)

func GenerateDeployStakingCollectionScript() []byte {
	return assets.MustAsset(deployStakingCollectionFilename)
}
