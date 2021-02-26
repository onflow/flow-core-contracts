package test

import (
	"testing"

	"github.com/onflow/cadence"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
)

func TestEpochDeployment(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		0,             // start epoch counter
		70,            // num views per epoch
		50,            // num views for staking auction
		2,             // num views for DKG phase
		4,             // num collector clusters
		"lolsoRandom") // random source

	// Verify that the global config data for epochs was initialized correctly
	verifyConfigMetadata(t, b, env,
		ConfigMetadata{
			currentEpochCounter:      0,
			proposedEpochCounter:     1,
			currentEpochPhase:        0,
			numViewsInEpoch:          70,
			numViewsInStakingAuction: 50,
			numViewsInDKGPhase:       2,
			numCollectorClusters:     4})

	// Verify that the current epoch was initialized correctly
	verifyEpochMetadata(t, b, env,
		EpochMetadata{
			counter:           0,
			seed:              "lolsoRandom",
			startView:         0,
			endView:           69,
			stakingEndView:    49,
			collectorClusters: nil,
			clusterQCs:        nil,
			dkgKeys:           nil})
}

func TestEpochMetadataChange(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	idTableAddress := initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		0,             // start epoch counter
		70,            // num views per epoch
		50,            // num views for staking auction
		2,             // num views for DKG phase
		4,             // num collector clusters
		"lolsoRandom") // random source

	t.Run("Should be able to change the configurable metadata during the staking auction", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochViewsScript(env), idTableAddress)

		_ = tx.AddArgument(cadence.NewUInt64(80))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateStakingViewsScript(env), idTableAddress)

		_ = tx.AddArgument(cadence.NewUInt64(60))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateDKGViewsScript(env), idTableAddress)

		_ = tx.AddArgument(cadence.NewUInt64(4))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateNumClustersScript(env), idTableAddress)

		_ = tx.AddArgument(cadence.NewUInt16(2))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		// Verify that the global config data for epochs was initialized correctly
		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      0,
				proposedEpochCounter:     1,
				currentEpochPhase:        0,
				numViewsInEpoch:          80,
				numViewsInStakingAuction: 60,
				numViewsInDKGPhase:       4,
				numCollectorClusters:     2})

	})

}
