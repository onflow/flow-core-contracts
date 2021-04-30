package test

import (
	"fmt"
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
)

const (
	numEpochAccounts  = 4
	numClusters       = 4
	startEpochCounter = 0
	numEpochViews     = 70
	numStakingViews   = 50
	numDKGViews       = 2
	randomSource      = "lolsoRandom"
	totalRewards      = "1250000.0"
	rewardAPY         = "0.05"
)

func TestEpochDeployment(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardAPY)

	// Verify that the global config data for epochs was initialized correctly
	verifyConfigMetadata(t, b, env,
		ConfigMetadata{
			currentEpochCounter:      startEpochCounter,
			proposedEpochCounter:     startEpochCounter + 1,
			currentEpochPhase:        0,
			numViewsInEpoch:          numEpochViews,
			numViewsInStakingAuction: numStakingViews,
			numViewsInDKGPhase:       numDKGViews,
			numCollectorClusters:     numClusters,
			rewardPercentage:         rewardAPY})

	// Verify that the current epoch was initialized correctly
	verifyEpochMetadata(t, b, env,
		EpochMetadata{
			counter:               startEpochCounter,
			seed:                  "lolsoRandom",
			startView:             0,
			endView:               numEpochViews - 1,
			stakingEndView:        numStakingViews - 1,
			totalRewards:          totalRewards,
			rewardsBreakdownArray: 0,
			rewardsPaid:           false,
			collectorClusters:     nil,
			clusterQCs:            nil,
			dkgKeys:               nil})

}

func TestEpochClusters(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardAPY)

	t.Run("Should be able to randomize an array of strings", func(t *testing.T) {

		idArray := cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID), cadence.NewString(maxID), cadence.NewString(accessID)})
		result := executeScriptAndCheck(t, b, templates.GenerateGetRandomizeScript(env), [][]byte{jsoncdc.MustEncode(idArray)})
		assertEqual(t, 4, len(result.(cadence.Array).Values))

		// TODO: Make sure that the ids in the array all match the provided IDs and are in a different order
	})

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, accountKeys, numEpochAccounts)
	ids, _, _ := generateNodeIDs(numEpochAccounts)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		ids)

	t.Run("Should be able to create collector clusters from an array of ids signed up for staking", func(t *testing.T) {
		idArray := cadence.NewArray([]cadence.Value{cadence.NewString(ids[0]), cadence.NewString(ids[1]), cadence.NewString(ids[2]), cadence.NewString(ids[3])})
		result := executeScriptAndCheck(t, b, templates.GenerateGetCreateClustersScript(env), [][]byte{jsoncdc.MustEncode(idArray)})
		assertEqual(t, 4, len(result.(cadence.Array).Values))

		// TODO: Make sure that the clusters are correct and are in a different order than the original array
	})

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
		"lolsoRandom", // random source
		rewardAPY)

	t.Run("Should be able to change the configurable metadata during the staking auction", func(t *testing.T) {

		// Should fail because the sum of the staking phase and dkg phases is greater than epoch
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(5))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		// Should succeed because it is greater than the sum of the views
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(12))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		// Should fail because staking+dkg views is greater than epoch views
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateStakingViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(10))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		// Should succeed because the sum is less than epoch views
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateStakingViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(4))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		// should fail because DKG views are too large
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateDKGViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(3))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		// should succeed because DKG views are fine
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateDKGViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(2))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		// Should succeed because there is no restriction on this
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateNumClustersScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt16(2))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		// Should fail because it is > 1
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateRewardPercentageScript(env), idTableAddress)
		_ = tx.AddArgument(CadenceUFix64("2.04"))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		// Should succeed because it is < 1
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateRewardPercentageScript(env), idTableAddress)
		_ = tx.AddArgument(CadenceUFix64("0.04"))
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
				numViewsInEpoch:          12,
				numViewsInStakingAuction: 4,
				numViewsInDKGPhase:       2,
				numCollectorClusters:     2,
				rewardPercentage:         "0.04"})
	})

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, accountKeys, numEpochAccounts)
	ids, _, _ := generateNodeIDs(numEpochAccounts)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		ids)

	t.Run("Should not be able change metadata outside of Staking Auction", func(t *testing.T) {

		// advance to the epoch setup phase
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)

		// Should succeed because it is greater than the sum of the views
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(12))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		// Should succeed because the sum is less than epoch views
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateStakingViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(4))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		// should succeed because DKG views are fine
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateDKGViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(2))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		// Should succeed because there is no restriction on this
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateNumClustersScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt16(2))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		// Should fail because it is not the staking Auction
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateRewardPercentageScript(env), idTableAddress)
		_ = tx.AddArgument(CadenceUFix64("0.05"))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		// metadata should still be the same
		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      0,
				proposedEpochCounter:     1,
				currentEpochPhase:        1,
				numViewsInEpoch:          12,
				numViewsInStakingAuction: 4,
				numViewsInDKGPhase:       2,
				numCollectorClusters:     2,
				rewardPercentage:         "0.04"})

	})
}

func TestEpochAdvance(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	idTableAddress := initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardAPY)

	t.Run("Should not be able to advance to epoch committed or end epoch during staking", func(t *testing.T) {
		// try to advance to the epoch committed phase
		// should fail
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHCOMMITTED", true)

		// try to advance to the end epoch phase
		// should fail
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "ENDEPOCH", true)
	})

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, accountKeys, numEpochAccounts)
	ids, _, dkgIDs := generateNodeIDs(numEpochAccounts)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		ids)

	t.Run("Proposed metadata, QC, and DKG should have been created properly for epoch setup", func(t *testing.T) {

		// Advance to epoch Setup and make sure that the epoch cannot be ended
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)

		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      startEpochCounter,
				proposedEpochCounter:     startEpochCounter + 1,
				currentEpochPhase:        1,
				numViewsInEpoch:          numEpochViews,
				numViewsInStakingAuction: numStakingViews,
				numViewsInDKGPhase:       numDKGViews,
				numCollectorClusters:     numClusters,
				rewardPercentage:         rewardAPY})

		// Verify that the proposed epoch metadata was initialized correctly
		clusters := []Cluster{Cluster{index: 0, totalWeight: 100, size: 1},
			Cluster{index: 1, totalWeight: 0, size: 0},
			Cluster{index: 2, totalWeight: 0, size: 0},
			Cluster{index: 3, totalWeight: 0, size: 0}}

		verifyEpochMetadata(t, b, env,
			EpochMetadata{
				counter:               startEpochCounter + 1,
				seed:                  "",
				startView:             numEpochViews,
				endView:               2*numEpochViews - 1,
				stakingEndView:        numEpochViews + numStakingViews - 1,
				totalRewards:          "0.0",
				rewardsBreakdownArray: 0,
				rewardsPaid:           false,
				collectorClusters:     clusters,
				clusterQCs:            nil,
				dkgKeys:               nil})

		verifyEpochSetup(t, b, idTableAddress,
			EpochSetup{
				counter:            startEpochCounter + 1,
				nodeInfoLength:     numEpochAccounts,
				firstView:          numEpochViews,
				finalView:          2*numEpochViews - 1,
				collectorClusters:  clusters,
				randomSource:       "",
				dkgPhase1FinalView: numEpochViews + numStakingViews + numDKGViews - 1,
				dkgPhase2FinalView: numEpochViews + numStakingViews + 2*numDKGViews - 1,
				dkgPhase3FinalView: numEpochViews + numStakingViews + 3*numDKGViews - 1})

		// QC Contract Checks
		result := executeScriptAndCheck(t, b, templates.GenerateGetClusterWeightScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0)))})
		assert.Equal(t, cadence.NewUInt64(100), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetNodeWeightScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0))), jsoncdc.MustEncode(cadence.String(ids[0]))})
		assert.Equal(t, cadence.NewUInt64(100), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetClusterVoteThresholdScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0)))})
		assert.Equal(t, cadence.NewUInt64(67), result)

		// DKG Contract Checks
		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[1]))})
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetConsensusNodesScript(env), nil)
		assert.Equal(t, cadence.NewArray(dkgIDs), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGFinalSubmissionsScript(env), nil)
		assert.Equal(t, cadence.NewArray(make([]cadence.Value, 0)), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)

	})

	t.Run("Should not be able to advance to epoch committed or end epoch during epoch committed if nothing has happened", func(t *testing.T) {
		// try to advance to the epoch committed phase
		// will not panic, but no state has changed
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHCOMMITTED", false)

		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      startEpochCounter,
				proposedEpochCounter:     startEpochCounter + 1,
				currentEpochPhase:        1,
				numViewsInEpoch:          numEpochViews,
				numViewsInStakingAuction: numStakingViews,
				numViewsInDKGPhase:       numDKGViews,
				numCollectorClusters:     numClusters,
				rewardPercentage:         rewardAPY})

		// try to advance to the end epoch phase
		// will fail
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "ENDEPOCH", true)
	})

}

func TestEpochQCDKGNodeRegistration(t *testing.T) {
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
		"lolsoRandom", // random source
		rewardAPY)

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, accountKeys, numEpochAccounts)
	ids, _, _ := generateNodeIDs(numEpochAccounts)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		ids)

	// Advance to epoch Setup and make sure that the epoch cannot be ended
	advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)

	t.Run("Should not be able to register a QC voter or DKG participant for the wrong node types", func(t *testing.T) {

		// Should fail because nodes cannot register if it is during the staking auction
		// even if they are the correct node type
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterQCVoterScript(env), addresses[1])
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, addresses[1]},
			[]crypto.Signer{b.ServiceKey().Signer(), signers[1]},
			true,
		)

		// Should fail because nodes cannot register if it is during the staking auction
		// even if they are the correct node type
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterDKGParticipantScript(env), addresses[0])
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, addresses[0]},
			[]crypto.Signer{b.ServiceKey().Signer(), signers[0]},
			true,
		)
	})

	t.Run("Should be able to register a QC voter or DKG participant during epoch setup", func(t *testing.T) {

		// Should fail because nodes cannot register if it is during the staking auction
		// even if they are the correct node type
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterQCVoterScript(env), addresses[0])
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, addresses[0]},
			[]crypto.Signer{b.ServiceKey().Signer(), signers[0]},
			false,
		)

		// Should fail because nodes cannot register if it is during the staking auction
		// even if they are the correct node type
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterDKGParticipantScript(env), addresses[1])
		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, addresses[1]},
			[]crypto.Signer{b.ServiceKey().Signer(), signers[1]},
			false,
		)
	})
}

func TestEpochFullNodeRegistration(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	_ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		0,             // start epoch counter
		70,            // num views per epoch
		50,            // num views for staking auction
		2,             // num views for DKG phase
		4,             // num collector clusters
		"lolsoRandom", // random source
		rewardAPY)

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, publicKeys, signers := registerAndMintManyAccounts(t, b, accountKeys, numEpochAccounts)
	ids, _, _ := generateNodeIDs(numEpochAccounts)
	registerNodesForEpochs(t, b, env,
		addresses,
		signers,
		publicKeys,
		ids)
}

func TestEpochQCDKG(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	idTableAddress := initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardAPY)

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, accountKeys, numEpochAccounts)
	ids, _, _ := generateNodeIDs(numEpochAccounts)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		ids)

	// Advance to epoch Setup and make sure that the epoch cannot be ended
	advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)

	// Register a QC voter
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterQCVoterScript(env), addresses[0])
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, addresses[0]},
		[]crypto.Signer{b.ServiceKey().Signer(), signers[0]},
		false,
	)

	// Register a DKG Participant
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterDKGParticipantScript(env), addresses[1])
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, addresses[1]},
		[]crypto.Signer{b.ServiceKey().Signer(), signers[1]},
		false,
	)

	dkgKey1 := fmt.Sprintf("%0192d", admin)
	finalKeyStrings := make([]string, 2)
	finalKeyStrings[0] = dkgKey1
	finalKeyStrings[1] = dkgKey1
	finalSubmissionKeys := make([]cadence.Value, 2)
	finalSubmissionKeys[0] = cadence.NewString(dkgKey1)
	finalSubmissionKeys[1] = cadence.NewString(dkgKey1)

	t.Run("Can perform DKG actions during Epoch Setup but cannot advance until QC is complete", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), addresses[1])

		_ = tx.AddArgument(cadence.NewString("hello world!"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, addresses[1]},
			[]crypto.Signer{b.ServiceKey().Signer(), signers[1]},
			false,
		)

		finalSubmissionKeys[0] = cadence.NewString(dkgKey1)
		finalSubmissionKeys[1] = cadence.NewString(dkgKey1)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), addresses[1])

		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeys))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, addresses[1]},
			[]crypto.Signer{b.ServiceKey().Signer(), signers[1]},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		// try to advance to the epoch committed phase
		// will not panic, but no state has changed
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHCOMMITTED", false)

		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      startEpochCounter,
				proposedEpochCounter:     startEpochCounter + 1,
				currentEpochPhase:        1,
				numViewsInEpoch:          numEpochViews,
				numViewsInStakingAuction: numStakingViews,
				numViewsInDKGPhase:       numDKGViews,
				numCollectorClusters:     numClusters,
				rewardPercentage:         rewardAPY})

	})

	clusterQCs := make([][]string, numClusters)
	clusterQCs[0] = make([]string, 1)
	clusterQCs[0][0] = "0000000000000000000000000000000000000000000000000000000000000000"

	t.Run("Can perform QC actions during Epoch Setup and advance to EpochCommitted", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), addresses[0])

		_ = tx.AddArgument(cadence.NewString("0000000000000000000000000000000000000000000000000000000000000000"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, addresses[0]},
			[]crypto.Signer{b.ServiceKey().Signer(), signers[0]},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[0]))})
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetVotingCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		// Advance to epoch committed
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHCOMMITTED", false)

		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      startEpochCounter,
				proposedEpochCounter:     startEpochCounter + 1,
				currentEpochPhase:        2,
				numViewsInEpoch:          numEpochViews,
				numViewsInStakingAuction: numStakingViews,
				numViewsInDKGPhase:       numDKGViews,
				numCollectorClusters:     numClusters,
				rewardPercentage:         rewardAPY})

		verifyEpochCommitted(t, b, idTableAddress,
			EpochCommitted{
				counter:    startEpochCounter + 1,
				dkgPubKeys: finalKeyStrings,
				clusterQCs: clusterQCs})

	})

	t.Run("Can end the Epoch and start a new Epoch", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochCalculateSetRewardsScript(env), idTableAddress)

		_ = tx.AddArgument(CadenceUFix64("1300000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		// Advance to new epoch
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "ENDEPOCH", false)

		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      startEpochCounter + 1,
				proposedEpochCounter:     startEpochCounter + 2,
				currentEpochPhase:        0,
				numViewsInEpoch:          numEpochViews,
				numViewsInStakingAuction: numStakingViews,
				numViewsInDKGPhase:       numDKGViews,
				numCollectorClusters:     numClusters,
				rewardPercentage:         rewardAPY})

		clusters := []Cluster{Cluster{index: 0, totalWeight: 100, size: 1},
			Cluster{index: 1, totalWeight: 0, size: 0},
			Cluster{index: 2, totalWeight: 0, size: 0},
			Cluster{index: 3, totalWeight: 0, size: 0}}

		verifyEpochMetadata(t, b, env,
			EpochMetadata{
				counter:               startEpochCounter + 1,
				seed:                  "",
				startView:             numEpochViews,
				endView:               2*numEpochViews - 1,
				stakingEndView:        numEpochViews + numStakingViews - 1,
				totalRewards:          "1300000.0",
				rewardsBreakdownArray: 0,
				rewardsPaid:           false,
				collectorClusters:     clusters,
				clusterQCs:            clusterQCs,
				dkgKeys:               finalKeyStrings})

	})
}

func TestEpochReset(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	idTableAddress := initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardAPY)

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, accountKeys, numEpochAccounts)
	ids, _, _ := generateNodeIDs(numEpochAccounts)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		ids)

	// Advance to epoch Setup and make sure that the epoch cannot be ended
	advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)

	// Register a QC voter
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterQCVoterScript(env), addresses[0])
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, addresses[0]},
		[]crypto.Signer{b.ServiceKey().Signer(), signers[0]},
		false,
	)

	// Register a DKG Participant
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterDKGParticipantScript(env), addresses[1])
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, addresses[1]},
		[]crypto.Signer{b.ServiceKey().Signer(), signers[1]},
		false,
	)

	clusterQCs := make([][]string, numClusters)
	clusterQCs[0] = make([]string, 1)
	clusterQCs[0][0] = "0000000000000000000000000000000000000000000000000000000000000000"

	t.Run("Can perform QC actions during Epoch Setup but cannot advance to EpochCommitted if DKG isn't complete", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), addresses[0])

		_ = tx.AddArgument(cadence.NewString("0000000000000000000000000000000000000000000000000000000000000000"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, addresses[0]},
			[]crypto.Signer{b.ServiceKey().Signer(), signers[0]},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[0]))})
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetVotingCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		// will not fail but the state hasn't changed since we cannot advance to epoch committed
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHCOMMITTED", false)

		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      startEpochCounter,
				proposedEpochCounter:     startEpochCounter + 1,
				currentEpochPhase:        1,
				numViewsInEpoch:          numEpochViews,
				numViewsInStakingAuction: numStakingViews,
				numViewsInDKGPhase:       numDKGViews,
				numCollectorClusters:     numClusters,
				rewardPercentage:         rewardAPY})

	})

	t.Run("Can reset the epoch and have everything return to normal", func(t *testing.T) {

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateResetEpochScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewString("stillSoRandom"))
		_ = tx.AddArgument(CadenceUFix64("1300000.0"))
		_ = tx.AddArgument(cadence.NewArray([]cadence.Value{}))
		_ = tx.AddArgument(cadence.NewArray([]cadence.Value{}))
		_ = tx.AddArgument(cadence.NewArray([]cadence.Value{}))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		verifyEpochMetadata(t, b, env,
			EpochMetadata{
				counter:               startEpochCounter + 1,
				seed:                  "stillSoRandom",
				startView:             0,
				endView:               numEpochViews - 1,
				stakingEndView:        numStakingViews - 1,
				totalRewards:          "1300000.0",
				rewardsBreakdownArray: 0,
				rewardsPaid:           false,
				collectorClusters:     nil,
				clusterQCs:            nil,
				dkgKeys:               nil})

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetQCEnabledScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)
	})
}
