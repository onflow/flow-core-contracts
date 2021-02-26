package test

import (
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"

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

func TestEpochClusters(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	_ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		0,             // start epoch counter
		8,             // num views per epoch
		3,             // num views for staking auction
		1,             // num views for DKG phase
		1,             // num collector clusters
		"lolsoRandom") // random source

	t.Run("Should be able to randomize an array of strings", func(t *testing.T) {

		idArray := cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID), cadence.NewString(maxID), cadence.NewString(accessID)})
		result := executeScriptAndCheck(t, b, templates.GenerateGetRandomizeScript(env), [][]byte{jsoncdc.MustEncode(idArray)})
		assertEqual(t, 4, len(result.(cadence.Array).Values))
	})

	// t.Run("Should be able to create collector clusters from an array of ids", func(t *testing.T) {

	// 	idArray := cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID), cadence.NewString(maxID), cadence.NewString(accessID)})
	// 	result := executeScriptAndCheck(t, b, templates.GenerateGetCreateClustersScript(env), [][]byte{jsoncdc.MustEncode(idArray)})
	// 	assertEqual(t, 4, len(result.(cadence.Array).Values))
	// })

}

func TestEpochPhaseMetadataChange(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	idTableAddress := initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		0,             // start epoch counter
		8,             // num views per epoch
		3,             // num views for staking auction
		1,             // num views for DKG phase
		1,             // num collector clusters
		"lolsoRandom") // random source

	t.Run("Should be able to change the configurable metadata during the staking auction", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(10))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateStakingViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(4))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateDKGViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(2))

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
				numViewsInEpoch:          10,
				numViewsInStakingAuction: 4,
				numViewsInDKGPhase:       2,
				numCollectorClusters:     2})
	})

}

func TestEpochStakingAuction(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	_ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		0,             // start epoch counter
		8,             // num views per epoch
		3,             // num views for staking auction
		1,             // num views for DKG phase
		1,             // num collector clusters
		"lolsoRandom") // random source

	// t.Run("Should be able to advance to epoch setup", func(t *testing.T) {

	// 	advanceView(t, b, env, idTableAddress, IDTableSigner, 1, 0)

	// 	verifyConfigMetadata(t, b, env,
	// 		ConfigMetadata{
	// 			currentEpochCounter:      0,
	// 			proposedEpochCounter:     1,
	// 			currentEpochPhase:        1,
	// 			numViewsInEpoch:          10,
	// 			numViewsInStakingAuction: 4,
	// 			numViewsInDKGPhase:       2,
	// 			numCollectorClusters:     2})

	// })

}
