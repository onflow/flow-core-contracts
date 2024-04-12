package test

import (
	"encoding/hex"
	"fmt"
	"math/rand"
	"testing"
	"time"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/crypto"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
	"github.com/onflow/flow-go-sdk"
	sdkcrypto "github.com/onflow/flow-go-sdk/crypto"
)

const (
	numEpochAccounts     = 6
	numClusters          = 2
	startEpochCounter    = 0
	numEpochViews        = 70
	numStakingViews      = 50
	numDKGViews          = 2
	randomSource         = "lolsoRandom"
	totalRewards         = "1250000.0"
	rewardIncreaseFactor = "0.00093871"
	// TODO: import the constant from the flow-go/module/signature package
	// once flow-go is updated.
	collectorVoteTag = "FLOW-Collector_Vote-V00-CS00-with-"
)

func TestEpochDeployment(t *testing.T) {
	b, _, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	_, startView := initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

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
			rewardPercentage:         rewardIncreaseFactor})

	verifyEpochTimingConfig(t, b, env,
		EpochTimingConfig{
			duration:     numEpochViews,
			refCounter:   startEpochCounter,
			refTimestamp: uint64(time.Now().Unix()) + numEpochViews,
		})

	// Verify that the current epoch was initialized correctly
	verifyEpochMetadata(t, b, env,
		EpochMetadata{
			counter:               startEpochCounter,
			seed:                  "lolsoRandom",
			startView:             startView,
			endView:               startView + numEpochViews - 1,
			stakingEndView:        startView + numStakingViews - 1,
			totalRewards:          totalRewards,
			rewardsBreakdownArray: 0,
			rewardsPaid:           false,
			collectorClusters:     nil,
			clusterQCs:            nil,
			dkgKeys:               nil})

}

func TestEpochClusters(t *testing.T) {
	b, _, accountKeys, env := newTestSetup(t)

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
		rewardIncreaseFactor)

	t.Run("Should be able to randomize an array of strings", func(t *testing.T) {

		adminString, _ := cadence.NewString(adminID)
		joshString, _ := cadence.NewString(joshID)
		maxString, _ := cadence.NewString(maxID)
		accessString, _ := cadence.NewString(accessID)
		idArray := cadence.NewArray([]cadence.Value{adminString, joshString, maxString, accessString})
		result := executeScriptAndCheck(t, b, templates.GenerateGetRandomizeScript(env), [][]byte{jsoncdc.MustEncode(idArray)})
		assertEqual(t, 4, len(result.(cadence.Array).Values))

		// TODO: Make sure that the ids in the array all match the provided IDs and are in a different order
	})

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, env, accountKeys, numEpochAccounts)
	ids, _, _ := generateNodeIDs(numEpochAccounts)
	_, stakingPublicKeys, _, networkingPublicKeys := generateManyNodeKeys(t, numEpochAccounts)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		stakingPublicKeys,
		networkingPublicKeys,
		ids)

	t.Run("Should be able to create collector clusters from an array of ids signed up for staking", func(t *testing.T) {
		string0, _ := cadence.NewString(ids[0])
		string1, _ := cadence.NewString(ids[1])
		string2, _ := cadence.NewString(ids[2])
		string3, _ := cadence.NewString(ids[3])
		idArray := cadence.NewArray([]cadence.Value{string0, string1, string2, string3})
		result := executeScriptAndCheck(t, b, templates.GenerateGetCreateClustersScript(env), [][]byte{jsoncdc.MustEncode(idArray)})
		assertEqual(t, 2, len(result.(cadence.Array).Values))

		// TODO: Make sure that the clusters are correct and are in a different order than the original array
	})

}

func TestEpochPhaseMetadataChange(t *testing.T) {
	b, _, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	idTableAddress, _ := initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		0,             // start epoch counter
		8,             // num views per epoch
		3,             // num views for staking auction
		1,             // num views for DKG phase
		1,             // num collector clusters
		"lolsoRandom", // random source
		rewardIncreaseFactor)

	t.Run("Should be able to change the configurable metadata during the staking auction", func(t *testing.T) {
		// Should fail to set epoch config with invalid config sum of the staking phase and dkg phases is greater than epoch
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochConfigScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(5)) // dkg
		_ = tx.AddArgument(cadence.NewUInt64(5)) // staking
		_ = tx.AddArgument(cadence.NewUInt64(5)) // epoch
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			true,
		)

		// Should set epoch config successfully when increasing the epochs views
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochConfigScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(2))  // dkg
		_ = tx.AddArgument(cadence.NewUInt64(4))  // staking
		_ = tx.AddArgument(cadence.NewUInt64(12)) // epoch
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		// Should set epoch config successfully when decreasing epochs views
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochConfigScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(1)) // dkg
		_ = tx.AddArgument(cadence.NewUInt64(2)) // staking
		_ = tx.AddArgument(cadence.NewUInt64(6)) // epoch
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		// Should fail because the sum of the staking phase and dkg phases is greater than epoch
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(5))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			true,
		)

		// Should succeed because it is greater than the sum of the views
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(12))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		// Should fail because staking+dkg views is greater than epoch views
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateStakingViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(10))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			true,
		)

		// Should succeed because the sum is less than epoch views
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateStakingViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(4))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		// should fail because DKG views are too large
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateDKGViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(3))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			true,
		)

		// should succeed because DKG views are fine
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateDKGViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(2))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		// Should succeed because there is no restriction on this
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateNumClustersScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt16(2))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		// Should fail because it is > 1
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateRewardPercentageScript(env), idTableAddress)
		_ = tx.AddArgument(CadenceUFix64("2.04"))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			true,
		)

		// Should succeed because it is < 1
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateRewardPercentageScript(env), idTableAddress)
		_ = tx.AddArgument(CadenceUFix64("0.04"))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
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

	t.Run("should be able to update timing config when staking enabled (Staking phase)", func(t *testing.T) {
		timingConfig := EpochTimingConfig{
			duration:     rand.Uint64() % 100_000,
			refCounter:   0,
			refTimestamp: uint64(time.Now().Unix()),
		}

		t.Run("invalid EpochTimingConfig", func(t *testing.T) {
			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochTimingConfigScript(env), idTableAddress)
			_ = tx.AddArgument(CadenceUInt64(timingConfig.duration))
			// Use a reference counter in the future, which validates the precondition
			_ = tx.AddArgument(CadenceUInt64(timingConfig.refCounter + 100))
			_ = tx.AddArgument(CadenceUInt64(timingConfig.refTimestamp))
			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				true,
			)
		})

		t.Run("valid EpochTimingConfig", func(t *testing.T) {
			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochTimingConfigScript(env), idTableAddress)
			_ = tx.AddArgument(CadenceUInt64(timingConfig.duration))
			_ = tx.AddArgument(CadenceUInt64(timingConfig.refCounter))
			_ = tx.AddArgument(CadenceUInt64(timingConfig.refTimestamp))
			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				false,
			)
			// timing config should be updated
			verifyEpochTimingConfig(t, b, env, timingConfig)
		})
	})

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, env, accountKeys, numEpochAccounts)
	ids, _, _ := generateNodeIDs(numEpochAccounts)
	_, stakingPublicKeys, _, networkingPublicKeys := generateManyNodeKeys(t, numEpochAccounts)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		stakingPublicKeys,
		networkingPublicKeys,
		ids)

	// Set the approved node list
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetApprovedNodesScript(env), idTableAddress)

	approvedNodeIDs := generateCadenceNodeDictionary(ids)
	err := tx.AddArgument(approvedNodeIDs)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]sdkcrypto.Signer{IDTableSigner},
		false,
	)

	t.Run("Should not be able change metadata outside of Staking Auction", func(t *testing.T) {

		// advance to the epoch setup phase
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)

		// Should succeed because it is greater than the sum of the views
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(12))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			true,
		)

		// Should succeed because the sum is less than epoch views
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateStakingViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(4))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			true,
		)

		// should succeed because DKG views are fine
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateDKGViewsScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt64(2))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			true,
		)

		// Should succeed because there is no restriction on this
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateNumClustersScript(env), idTableAddress)
		_ = tx.AddArgument(cadence.NewUInt16(2))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			true,
		)

		// Should fail because it is not the staking Auction
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateRewardPercentageScript(env), idTableAddress)
		_ = tx.AddArgument(CadenceUFix64("0.05"))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
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

	t.Run("should be able to update timing config when staking disabled (Setup/Commit phases)", func(t *testing.T) {
		timingConfig := EpochTimingConfig{
			duration:     rand.Uint64() % 100_000,
			refCounter:   0,
			refTimestamp: uint64(time.Now().Unix()),
		}

		t.Run("invalid EpochTimingConfig", func(t *testing.T) {
			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochTimingConfigScript(env), idTableAddress)
			_ = tx.AddArgument(CadenceUInt64(timingConfig.duration))
			// Use a reference counter in the future, which validates the precondition
			_ = tx.AddArgument(CadenceUInt64(timingConfig.refCounter + 100))
			_ = tx.AddArgument(CadenceUInt64(timingConfig.refTimestamp))
			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				true,
			)
		})

		t.Run("valid EpochTimingConfig", func(t *testing.T) {
			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateEpochTimingConfigScript(env), idTableAddress)
			_ = tx.AddArgument(CadenceUInt64(timingConfig.duration))
			_ = tx.AddArgument(CadenceUInt64(timingConfig.refCounter))
			_ = tx.AddArgument(CadenceUInt64(timingConfig.refTimestamp))
			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				false,
			)
			// timing config should be updated
			verifyEpochTimingConfig(t, b, env, timingConfig)
		})
	})
}

func TestEpochTiming(t *testing.T) {
	b, _, accountKeys, env := newTestSetup(t)

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
		rewardIncreaseFactor)

	epochTimingConfigResult := executeScriptAndCheck(t, b, templates.GenerateGetEpochTimingConfigScript(env), nil)

	t.Run("should be able to observe end times for current epoch", func(t *testing.T) {
		gotEndTimeCdc := executeScriptAndCheck(t, b, templates.GenerateGetTargetEndTimeForEpochScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt64(startEpochCounter))})
		gotEndTime := gotEndTimeCdc.ToGoValue().(uint64)
		expectedEndTime := expectedTargetEndTime(epochTimingConfigResult, startEpochCounter)
		assert.Equal(t, expectedEndTime, gotEndTime)

		// sanity check: should be within 10 minutes of the current time
		gotEndTimeParsed := time.Unix(int64(gotEndTime), 0)
		assert.InDelta(t, time.Now().Unix(), gotEndTimeParsed.Unix(), float64(10*time.Minute))
		gotEndTimeParsed.Sub(time.Now())
	})

	t.Run("should be able to observe end times for future epochs", func(t *testing.T) {
		var lastEndTime uint64
		for _, epoch := range []uint64{1, 2, 3, 10, 100, 1000, 10_000} {
			gotEndTimeCdc := executeScriptAndCheck(t, b, templates.GenerateGetTargetEndTimeForEpochScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt64(epoch))})
			gotEndTime := gotEndTimeCdc.ToGoValue().(uint64)
			expectedEndTime := expectedTargetEndTime(epochTimingConfigResult, epoch)
			assert.Equal(t, expectedEndTime, gotEndTime)

			// sanity check: target end time should be strictly increasing
			if lastEndTime > 0 {
				assert.Greater(t, gotEndTime, lastEndTime)
			}

			lastEndTime = gotEndTime
		}
	})
}

func TestEpochAdvance(t *testing.T) {
	b, adapter, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	idTableAddress, startView := initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	t.Run("Should not be able to advance to epoch commit or end epoch during staking", func(t *testing.T) {
		// try to advance to the epoch commit phase
		// should fail
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHCOMMIT", true)

		// try to advance to the end epoch phase
		// should fail
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "ENDEPOCH", true)
	})

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, env, accountKeys, numEpochAccounts)
	ids, _, dkgIDs := generateNodeIDs(numEpochAccounts)
	_, stakingPublicKeys, _, networkingPublicKeys := generateManyNodeKeys(t, numEpochAccounts)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		stakingPublicKeys,
		networkingPublicKeys,
		ids)

	// Set the approved node list
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetApprovedNodesScript(env), idTableAddress)

	approvedNodeIDs := generateCadenceNodeDictionary(ids)
	err := tx.AddArgument(approvedNodeIDs)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]sdkcrypto.Signer{IDTableSigner},
		false,
	)

	t.Run("Proposed metadata, QC, and DKG should have been created properly for epoch setup", func(t *testing.T) {

		epochTimingConfigResult := executeScriptAndCheck(t, b, templates.GenerateGetEpochTimingConfigScript(env), nil)

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
				rewardPercentage:         rewardIncreaseFactor})

		// Verify that the proposed epoch metadata was initialized correctly
		clusters := []Cluster{{index: 0, totalWeight: 100, size: 1},
			{index: 1, totalWeight: 100, size: 1}}

		verifyEpochMetadata(t, b, env,
			EpochMetadata{
				counter:               startEpochCounter + 1,
				seed:                  "",
				startView:             startView + numEpochViews,
				endView:               startView + 2*numEpochViews - 1,
				stakingEndView:        startView + numEpochViews + numStakingViews - 1,
				totalRewards:          "0.0",
				rewardsBreakdownArray: 0,
				rewardsPaid:           false,
				collectorClusters:     clusters,
				clusterQCs:            nil,
				dkgKeys:               nil})

		verifyEpochTimingConfig(t, b, env,
			EpochTimingConfig{
				duration:     numEpochViews,
				refCounter:   startEpochCounter,
				refTimestamp: uint64(time.Now().Unix()) + numEpochViews,
			})

		verifyEpochSetup(t, b, adapter, idTableAddress,
			EpochSetup{
				counter:            startEpochCounter + 1,
				nodeInfoLength:     numEpochAccounts,
				firstView:          startView + numEpochViews,
				finalView:          startView + 2*numEpochViews - 1,
				collectorClusters:  clusters,
				randomSource:       "",
				dkgPhase1FinalView: startView + numEpochViews + numStakingViews + numDKGViews - 1,
				dkgPhase2FinalView: startView + numEpochViews + numStakingViews + 2*numDKGViews - 1,
				dkgPhase3FinalView: startView + numEpochViews + numStakingViews + 3*numDKGViews - 1,
				targetDuration:     numEpochViews,
				targetEndTime:      expectedTargetEndTime(epochTimingConfigResult, startEpochCounter+1),
			})

		// QC Contract Checks
		result := executeScriptAndCheck(t, b, templates.GenerateGetClusterWeightScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0)))})
		assert.Equal(t, cadence.NewUInt64(100), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetNodeWeightScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(1))), jsoncdc.MustEncode(cadence.String(ids[0]))})
		result2 := executeScriptAndCheck(t, b, templates.GenerateGetNodeWeightScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0))), jsoncdc.MustEncode(cadence.String(ids[0]))})
		assert.Equal(t, cadence.NewUInt64(100), result.(cadence.UInt64)+result2.(cadence.UInt64))

		result = executeScriptAndCheck(t, b, templates.GenerateGetClusterVoteThresholdScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0)))})
		assert.Equal(t, cadence.NewUInt64(67), result)

		// DKG Contract Checks
		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[1]))})
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetConsensusNodesScript(env), nil)
		assert.Equal(t, cadence.NewArray(dkgIDs).WithType(cadence.NewVariableSizedArrayType(cadence.NewStringType())), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGFinalSubmissionsScript(env), nil)
		assert.Equal(t, 0, len(result.(cadence.Array).Values))

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)

	})

	t.Run("Should not be able to advance to epoch commit or end epoch during epoch commit if nothing has happened", func(t *testing.T) {
		// try to advance to the epoch commit phase
		// will not panic, but no state has changed
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHCOMMIT", false)

		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      startEpochCounter,
				proposedEpochCounter:     startEpochCounter + 1,
				currentEpochPhase:        1,
				numViewsInEpoch:          numEpochViews,
				numViewsInStakingAuction: numStakingViews,
				numViewsInDKGPhase:       numDKGViews,
				numCollectorClusters:     numClusters,
				rewardPercentage:         rewardIncreaseFactor})

		// try to advance to the end epoch phase
		// will fail
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "ENDEPOCH", true)
	})

}

func TestEpochQCDKGNodeRegistration(t *testing.T) {
	b, _, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	idTableAddress, _ := initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		0,             // start epoch counter
		70,            // num views per epoch
		50,            // num views for staking auction
		2,             // num views for DKG phase
		2,             // num collector clusters
		"lolsoRandom", // random source
		rewardIncreaseFactor)

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, env, accountKeys, numEpochAccounts)
	ids, _, _ := generateNodeIDs(numEpochAccounts)
	_, stakingPublicKeys, _, networkingPublicKeys := generateManyNodeKeys(t, numEpochAccounts)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		stakingPublicKeys,
		networkingPublicKeys,
		ids)

	// Set the approved node list
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetApprovedNodesScript(env), idTableAddress)

	approvedNodeIDs := generateCadenceNodeDictionary(ids)
	err := tx.AddArgument(approvedNodeIDs)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]sdkcrypto.Signer{IDTableSigner},
		false,
	)

	// Advance to epoch Setup and make sure that the epoch cannot be ended
	advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)

	t.Run("Should not be able to register a QC voter or DKG participant for the wrong node types", func(t *testing.T) {

		// Should fail because nodes cannot register if it is during the staking auction
		// even if they are the correct node type
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterQCVoterScript(env), addresses[1])
		signAndSubmit(
			t, b, tx,
			[]flow.Address{addresses[1]},
			[]sdkcrypto.Signer{signers[1]},
			true,
		)

		// Should fail because nodes cannot register if it is during the staking auction
		// even if they are the correct node type
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterDKGParticipantScript(env), addresses[0])
		signAndSubmit(
			t, b, tx,
			[]flow.Address{addresses[0]},
			[]sdkcrypto.Signer{signers[0]},
			true,
		)
	})

	t.Run("Should be able to register a QC voter or DKG participant during epoch setup", func(t *testing.T) {

		// Should fail because nodes cannot register if it is during the staking auction
		// even if they are the correct node type
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterQCVoterScript(env), addresses[0])
		signAndSubmit(
			t, b, tx,
			[]flow.Address{addresses[0]},
			[]sdkcrypto.Signer{signers[0]},
			false,
		)

		// Should fail because nodes cannot register if it is during the staking auction
		// even if they are the correct node type
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterDKGParticipantScript(env), addresses[1])
		signAndSubmit(
			t, b, tx,
			[]flow.Address{addresses[1]},
			[]sdkcrypto.Signer{signers[1]},
			false,
		)
	})
}

func TestEpochFullNodeRegistration(t *testing.T) {
	b, _, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		0,             // start epoch counter
		70,            // num views per epoch
		50,            // num views for staking auction
		2,             // num views for DKG phase
		4,             // num collector clusters
		"lolsoRandom", // random source
		rewardIncreaseFactor)

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, publicKeys, signers := registerAndMintManyAccounts(t, b, env, accountKeys, numEpochAccounts)
	ids, _, _ := generateNodeIDs(numEpochAccounts)
	_, stakingPublicKeys, _, networkingPublicKeys := generateManyNodeKeys(t, numEpochAccounts)
	registerNodesForEpochs(t, b, env,
		addresses,
		signers,
		publicKeys,
		ids,
		stakingPublicKeys,
		networkingPublicKeys,
	)

}

func TestEpochQCDKG(t *testing.T) {
	b, adapter, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	idTableAddress, startView := initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		2,                 // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, env, accountKeys, numEpochAccounts)
	ids, _, _ := generateNodeIDs(numEpochAccounts)
	stakingPrivateKeys, stakingPublicKeys, _, networkingPublicKeys := generateManyNodeKeys(t, numEpochAccounts)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		stakingPublicKeys,
		networkingPublicKeys,
		ids)

	// Set the approved node list
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetApprovedNodesScript(env), idTableAddress)

	approvedNodeIDs := generateCadenceNodeDictionary(ids)
	err := tx.AddArgument(approvedNodeIDs)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]sdkcrypto.Signer{IDTableSigner},
		false,
	)

	// Advance to epoch Setup and make sure that the epoch cannot be ended
	advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)

	// Register a QC voter
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterQCVoterScript(env), addresses[0])
	signAndSubmit(
		t, b, tx,
		[]flow.Address{addresses[0]},
		[]sdkcrypto.Signer{signers[0]},
		false,
	)

	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterQCVoterScript(env), addresses[5])
	signAndSubmit(
		t, b, tx,
		[]flow.Address{addresses[5]},
		[]sdkcrypto.Signer{signers[5]},
		false,
	)

	// Register a DKG Participant
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterDKGParticipantScript(env), addresses[1])
	signAndSubmit(
		t, b, tx,
		[]flow.Address{addresses[1]},
		[]sdkcrypto.Signer{signers[1]},
		false,
	)

	dkgKey1 := fmt.Sprintf("%0192d", admin)
	finalKeyStrings := make([]string, 2)
	finalKeyStrings[0] = dkgKey1
	finalKeyStrings[1] = dkgKey1
	finalSubmissionKeys := make([]cadence.Value, 2)
	finalSubmissionKeys[0], _ = cadence.NewString(dkgKey1)
	finalSubmissionKeys[1], _ = cadence.NewString(dkgKey1)

	t.Run("Can perform DKG actions during Epoch Setup but cannot advance until QC is complete", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), addresses[1])

		_ = tx.AddArgument(CadenceString("hello world!"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{addresses[1]},
			[]sdkcrypto.Signer{signers[1]},
			false,
		)

		finalSubmissionKeys[0] = cadence.NewOptional(CadenceString(dkgKey1))
		finalSubmissionKeys[1] = cadence.NewOptional(CadenceString(dkgKey1))

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), addresses[1])

		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeys))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{addresses[1]},
			[]sdkcrypto.Signer{signers[1]},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		// try to advance to the epoch commit phase
		// will not panic, but no state has changed
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHCOMMIT", false)

		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      startEpochCounter,
				proposedEpochCounter:     startEpochCounter + 1,
				currentEpochPhase:        1,
				numViewsInEpoch:          numEpochViews,
				numViewsInStakingAuction: numStakingViews,
				numViewsInDKGPhase:       numDKGViews,
				numCollectorClusters:     2,
				rewardPercentage:         rewardIncreaseFactor})

	})

	clusterQCs := make([][]string, 2)
	clusterQCs[0] = make([]string, 2)
	clusterQCs[1] = make([]string, 2)

	collectorVoteHasher := crypto.NewExpandMsgXOFKMAC128(collectorVoteTag)

	t.Run("Can perform QC actions during Epoch Setup and advance to EpochCommit", func(t *testing.T) {

		msg, _ := hex.DecodeString("deadbeef")
		validSignature, err := stakingPrivateKeys[0].Sign(msg, collectorVoteHasher)
		validSignatureString := validSignature.String()[2:]
		assert.NoError(t, err)
		clusterQCs[0][0] = validSignatureString
		clusterQCs[0][1] = "deadbeef"

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), addresses[0])

		_ = tx.AddArgument(CadenceString(validSignatureString))
		_ = tx.AddArgument(CadenceString("deadbeef"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{addresses[0]},
			[]sdkcrypto.Signer{signers[0]},
			false,
		)

		msg, _ = hex.DecodeString("beefdead")
		validSignature, err = stakingPrivateKeys[5].Sign(msg, collectorVoteHasher)
		validSignatureString = validSignature.String()[2:]
		assert.NoError(t, err)
		clusterQCs[1][0] = validSignatureString
		clusterQCs[1][1] = "beefdead"

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), addresses[5])

		_ = tx.AddArgument(CadenceString(validSignatureString))
		_ = tx.AddArgument(CadenceString("beefdead"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{addresses[5]},
			[]sdkcrypto.Signer{signers[5]},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[0]))})
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetVotingCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		// Advance to epoch commit
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHCOMMIT", false)

		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      startEpochCounter,
				proposedEpochCounter:     startEpochCounter + 1,
				currentEpochPhase:        2,
				numViewsInEpoch:          numEpochViews,
				numViewsInStakingAuction: numStakingViews,
				numViewsInDKGPhase:       numDKGViews,
				numCollectorClusters:     2,
				rewardPercentage:         rewardIncreaseFactor})

		verifyEpochCommit(t, b, adapter, idTableAddress,
			EpochCommit{
				counter:    startEpochCounter + 1,
				dkgPubKeys: finalKeyStrings,
				clusterQCs: clusterQCs})

		// DKG and QC have not been disabled yet
		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetQCEnabledScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

	})

	t.Run("Can set bonus token amount to modify rewards calculation", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochSetBonusTokensScript(env), idTableAddress)

		_ = tx.AddArgument(CadenceUFix64("1000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetBonusTokensScript(env), nil)
		assertEqual(t, CadenceUFix64("1000000.0"), result)

	})

	t.Run("Can end the Epoch and start a new Epoch", func(t *testing.T) {

		result := executeScriptAndCheck(t, b, templates.GenerateGetFlowTotalSupplyScript(env), nil)
		assertEqual(t, CadenceUFix64("7000000000.0"), result)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochSetAutomaticRewardsScript(env), idTableAddress)

		_ = tx.AddArgument(cadence.NewBool(true))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochCalculateSetRewardsScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		// Advance to new epoch
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "ENDEPOCH", false)

		verifyEpochStart(t, b, adapter, idTableAddress,
			EpochStart{
				counter:        startEpochCounter + 1,
				firstView:      startView + numEpochViews,
				stakingEndView: startView + numEpochViews + numStakingViews - 1,
				finalView:      startView + 2*numEpochViews - 1,
				totalStaked:    "6750000.0",
				totalSupply:    "7000000000.0",
				rewards:        "6571204.6775",
			})

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochPayRewardsScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		// Verifies that the rewards from the previous epoch does not include the new epoch's amount
		verifyEpochTotalRewardsPaid(t, b, idTableAddress,
			EpochTotalRewardsPaid{
				total:      "0.0000",
				fromFees:   "0.0",
				minted:     "0.0000",
				feesBurned: "0.0000"})

		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      startEpochCounter + 1,
				proposedEpochCounter:     startEpochCounter + 2,
				currentEpochPhase:        0,
				numViewsInEpoch:          numEpochViews,
				numViewsInStakingAuction: numStakingViews,
				numViewsInDKGPhase:       numDKGViews,
				numCollectorClusters:     2,
				rewardPercentage:         rewardIncreaseFactor})

		clusters := []Cluster{{index: 0, totalWeight: 100, size: 1},
			{index: 1, totalWeight: 100, size: 1}}

		verifyEpochMetadata(t, b, env,
			EpochMetadata{
				counter:        startEpochCounter + 1,
				seed:           "",
				startView:      startView + numEpochViews,
				endView:        startView + 2*numEpochViews - 1,
				stakingEndView: startView + numEpochViews + numStakingViews - 1,
				// The calculation of the total rewards should have been reduced because of the bonus tokens
				// (total supply + current payount amount - bonus tokens) * reward increase factor
				// (7000000000 + 1250000 - 1000000) * 0.00093871 = 6,571,204.6775
				totalRewards:          "6571204.6775",
				rewardsBreakdownArray: 0,
				rewardsPaid:           false,
				collectorClusters:     clusters,
				clusterQCs:            clusterQCs,
				dkgKeys:               finalKeyStrings})

		// Make sure the payout is the same as the total rewards in the epoch metadata
		result = executeScriptAndCheck(t, b, templates.GenerateGetWeeklyPayoutScript(env), nil)
		assertEqual(t, CadenceUFix64("6571204.6775"), result)

		// DKG and QC are disabled at the end of the epoch
		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetQCEnabledScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)

		// The total supply did not increase because nobody was staked
		result = executeScriptAndCheck(t, b, templates.GenerateGetFlowTotalSupplyScript(env), nil)
		assertEqual(t, CadenceUFix64("7000000000.0"), result)

	})

	t.Run("Can set the rewards with high fee amount, which should not increase the supply at all", func(t *testing.T) {

		mintTokensForAccount(t, b, env, idTableAddress, "6572144.3875")

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositFeesScript(env), idTableAddress)

		_ = tx.AddArgument(CadenceUFix64("6572144.3875"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetFlowTotalSupplyScript(env), nil)
		assertEqual(t, CadenceUFix64("7006572144.3875"), result)

		// Advance to epoch Setup
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochCalculateSetRewardsScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		clusters := []Cluster{{index: 0, totalWeight: 100, size: 1},
			{index: 1, totalWeight: 100, size: 1}}

		verifyEpochMetadata(t, b, env,
			EpochMetadata{
				counter:        startEpochCounter + 2,
				seed:           "",
				startView:      startView + 2*numEpochViews,
				endView:        startView + 3*numEpochViews - 1,
				stakingEndView: startView + 2*numEpochViews + numStakingViews - 1,
				// This calculation does not add the rewards for the epoch because
				// they are not minted since they all come from fees
				// (7006572144.3875 - 1000000) * 0.00093871 = 6,576,200.62765799
				totalRewards:          "6576200.62765799",
				rewardsBreakdownArray: 0,
				rewardsPaid:           false,
				collectorClusters:     clusters,
				clusterQCs:            clusterQCs,
				dkgKeys:               finalKeyStrings})

		// Make sure the payout is the same as the total rewards in the epoch metadata
		result = executeScriptAndCheck(t, b, templates.GenerateGetWeeklyPayoutScript(env), nil)
		assertEqual(t, CadenceUFix64("6576200.62765799"), result)

	})
}

func TestEpochReset(t *testing.T) {
	b, _, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	idTableAddress, _ := initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, env, accountKeys, numEpochAccounts)
	ids, _, _ := generateNodeIDs(numEpochAccounts)
	stakingPrivateKeys, stakingPublicKeys, _, networkingPublicKeys := generateManyNodeKeys(t, numEpochAccounts)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		stakingPublicKeys,
		networkingPublicKeys,
		ids)

	// Set the approved node list
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetApprovedNodesScript(env), idTableAddress)

	approvedNodeIDs := generateCadenceNodeDictionary(ids)
	err := tx.AddArgument(approvedNodeIDs)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]sdkcrypto.Signer{IDTableSigner},
		false,
	)

	// Advance to epoch Setup and make sure that the epoch cannot be ended
	advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)

	// Register a QC voter
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterQCVoterScript(env), addresses[0])
	signAndSubmit(
		t, b, tx,
		[]flow.Address{addresses[0]},
		[]sdkcrypto.Signer{signers[0]},
		false,
	)

	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterQCVoterScript(env), addresses[5])
	signAndSubmit(
		t, b, tx,
		[]flow.Address{addresses[5]},
		[]sdkcrypto.Signer{signers[5]},
		false,
	)

	// Register a DKG Participant
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterDKGParticipantScript(env), addresses[1])
	signAndSubmit(
		t, b, tx,
		[]flow.Address{addresses[1]},
		[]sdkcrypto.Signer{signers[1]},
		false,
	)

	clusterQCs := make([][]string, numClusters)
	clusterQCs[0] = make([]string, 1)
	clusterQCs[1] = make([]string, 1)

	collectorVoteHasher := crypto.NewExpandMsgXOFKMAC128(collectorVoteTag)

	t.Run("Can perform QC actions during Epoch Setup but cannot advance to EpochCommit if DKG isn't complete", func(t *testing.T) {

		msg, _ := hex.DecodeString("deadbeef")
		validSignature, err := stakingPrivateKeys[0].Sign(msg, collectorVoteHasher)
		assert.NoError(t, err)
		validSignatureString := validSignature.String()[2:]
		clusterQCs[0][0] = validSignatureString

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), addresses[0])

		_ = tx.AddArgument(CadenceString(validSignatureString))
		_ = tx.AddArgument(CadenceString("deadbeef"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{addresses[0]},
			[]sdkcrypto.Signer{signers[0]},
			false,
		)

		msg, _ = hex.DecodeString("beefdead")
		validSignature, err = stakingPrivateKeys[5].Sign(msg, collectorVoteHasher)
		validSignatureString = validSignature.String()[2:]
		assert.NoError(t, err)
		clusterQCs[1][0] = validSignatureString

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), addresses[5])

		_ = tx.AddArgument(CadenceString(validSignatureString))
		_ = tx.AddArgument(CadenceString("beefdead"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{addresses[5]},
			[]sdkcrypto.Signer{signers[5]},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[0]))})
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetVotingCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		// will not fail but the state hasn't changed since we cannot advance to epoch commit
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHCOMMIT", false)

		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      startEpochCounter,
				proposedEpochCounter:     startEpochCounter + 1,
				currentEpochPhase:        1,
				numViewsInEpoch:          numEpochViews,
				numViewsInStakingAuction: numStakingViews,
				numViewsInDKGPhase:       numDKGViews,
				numCollectorClusters:     numClusters,
				rewardPercentage:         rewardIncreaseFactor})

	})

	t.Run("Cannot reset the epoch if the current epoch counter does not match", func(t *testing.T) {

		var startView uint64 = 100
		var stakingEndView uint64 = 120
		var endView uint64 = 200

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateResetEpochScript(env), idTableAddress)
		tx.AddArgument(cadence.NewUInt64(startEpochCounter + 1))
		tx.AddArgument(CadenceString("stillSoRandom"))
		tx.AddArgument(cadence.NewUInt64(startView))
		tx.AddArgument(cadence.NewUInt64(stakingEndView))
		tx.AddArgument(cadence.NewUInt64(endView))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			true,
		)
	})

	t.Run("Cannot reset the epoch if staking ends before start view", func(t *testing.T) {

		var startView uint64 = 100
		var stakingEndView uint64 = 99
		var endView uint64 = 200

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateResetEpochScript(env), idTableAddress)
		tx.AddArgument(cadence.NewUInt64(startEpochCounter))
		tx.AddArgument(CadenceString("stillSoRandom"))
		tx.AddArgument(cadence.NewUInt64(startView))
		tx.AddArgument(cadence.NewUInt64(stakingEndView))
		tx.AddArgument(cadence.NewUInt64(endView))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			true,
		)
	})

	t.Run("Cannot reset the epoch if staking ends after end view", func(t *testing.T) {

		var startView uint64 = 100
		var stakingEndView uint64 = 201
		var endView uint64 = 200

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateResetEpochScript(env), idTableAddress)
		tx.AddArgument(cadence.NewUInt64(startEpochCounter))
		tx.AddArgument(CadenceString("stillSoRandom"))
		tx.AddArgument(cadence.NewUInt64(startView))
		tx.AddArgument(cadence.NewUInt64(stakingEndView))
		tx.AddArgument(cadence.NewUInt64(endView))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			true,
		)
	})

	t.Run("Can reset the epoch and have everything return to normal", func(t *testing.T) {

		var startView uint64 = 100
		var stakingEndView uint64 = 120
		var endView uint64 = 160

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateResetEpochScript(env), idTableAddress)
		tx.AddArgument(cadence.NewUInt64(startEpochCounter))
		tx.AddArgument(CadenceString("stillSoRandom"))
		tx.AddArgument(cadence.NewUInt64(startView))
		tx.AddArgument(cadence.NewUInt64(stakingEndView))
		tx.AddArgument(cadence.NewUInt64(endView))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		verifyEpochMetadata(t, b, env,
			EpochMetadata{
				counter:               startEpochCounter + 1,
				seed:                  "stillSoRandom",
				startView:             startView,
				endView:               endView,
				stakingEndView:        stakingEndView,
				totalRewards:          "0.0",
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

	result := executeScriptAndCheck(t, b, templates.GenerateGetFlowTotalSupplyScript(env), nil)
	assertEqual(t, CadenceUFix64("7000000000.0"), result)

	t.Run("Can reset the epoch during the staking auction with automatic rewards enabled", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochSetAutomaticRewardsScript(env), idTableAddress)

		tx.AddArgument(cadence.NewBool(true))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		var startView uint64 = 100
		var stakingEndView uint64 = 120
		var endView uint64 = 160

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateResetEpochScript(env), idTableAddress)
		tx.AddArgument(cadence.NewUInt64(startEpochCounter + 1))
		tx.AddArgument(CadenceString("stillSoRandom"))
		tx.AddArgument(cadence.NewUInt64(startView))
		tx.AddArgument(cadence.NewUInt64(stakingEndView))
		tx.AddArgument(cadence.NewUInt64(endView))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		// Verify the current epoch's metadata to make sure rewards were calculated
		// properly after the reset and that they haven't been paid yet
		verifyEpochMetadata(t, b, env,
			EpochMetadata{
				counter:        startEpochCounter + 2,
				seed:           "stillSoRandom",
				startView:      startView,
				endView:        endView,
				stakingEndView: stakingEndView,
				// The calculation of the total rewards should have happened
				// because automatic rewards are enabled
				// (total supply + current payount amount - bonus tokens) * reward increase factor
				// (7000000000 + 1250000 - 0) * 0.00093871 = 6,571,204.6775
				totalRewards:          "6572143.3875",
				rewardsBreakdownArray: 0,
				rewardsPaid:           false,
				collectorClusters:     nil,
				clusterQCs:            nil,
				dkgKeys:               nil})

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochPayRewardsScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		// Verifies that the rewards from the previous epoch does not include the new epoch's amount
		verifyEpochTotalRewardsPaid(t, b, idTableAddress,
			EpochTotalRewardsPaid{
				total:      "1250000.00000000",
				fromFees:   "0.0",
				minted:     "1250000.00000000",
				feesBurned: "0.035"})

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[0]))})
		assertEqual(t, CadenceUFix64("249999.99300000"), result)

		// Rewards have already been paid, so this should not do anything
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochPayRewardsScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		// The nodes rewards should not have increased
		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[0]))})
		assertEqual(t, CadenceUFix64("249999.99300000"), result)
	})
}

func TestEpochRecover(t *testing.T) {
	b, _, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	idTableAddress, _ := initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, env, accountKeys, numEpochAccounts)
	ids, _, _ := generateNodeIDs(numEpochAccounts)
	// stakingPrivateKeys
	_, stakingPublicKeys, _, networkingPublicKeys := generateManyNodeKeys(t, numEpochAccounts)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		stakingPublicKeys,
		networkingPublicKeys,
		ids)

	// Set the approved node list
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetApprovedNodesScript(env), idTableAddress)

	approvedNodeIDs := generateCadenceNodeDictionary(ids)
	err := tx.AddArgument(approvedNodeIDs)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]sdkcrypto.Signer{IDTableSigner},
		false,
	)

	// Advance to epoch Setup and make sure that the epoch cannot be ended
	advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)

	// Register a QC voter
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterQCVoterScript(env), addresses[0])
	signAndSubmit(
		t, b, tx,
		[]flow.Address{addresses[0]},
		[]sdkcrypto.Signer{signers[0]},
		false,
	)

	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterQCVoterScript(env), addresses[5])
	signAndSubmit(
		t, b, tx,
		[]flow.Address{addresses[5]},
		[]sdkcrypto.Signer{signers[5]},
		false,
	)

	// Register a DKG Participant
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochRegisterDKGParticipantScript(env), addresses[1])
	signAndSubmit(
		t, b, tx,
		[]flow.Address{addresses[1]},
		[]sdkcrypto.Signer{signers[1]},
		false,
	)

	clusterQCs := make([][]string, numClusters)
	clusterQCs[0] = make([]string, 1)
	clusterQCs[1] = make([]string, 1)

	// collectorVoteHasher := crypto.NewExpandMsgXOFKMAC128(collectorVoteTag)

	t.Run("Can recover the epoch and have everything return to normal", func(t *testing.T) {

		var startView uint64 = 100
		var stakingEndView uint64 = 120
		var endView uint64 = 160

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateRecoverEpochScript(env), idTableAddress)
		tx.AddArgument(CadenceString("stillSoRandom"))
		tx.AddArgument(cadence.NewUInt64(startView))
		tx.AddArgument(cadence.NewUInt64(stakingEndView))
		tx.AddArgument(cadence.NewUInt64(endView))
		tx.AddArgument(cadence.NewArray([]cadence.Value{})) // collectorClusters
		tx.AddArgument(cadence.NewArray([]cadence.Value{})) // clusterQCVoteData

		dkgPubKeys := []string{"pubkey_1"}
		dkgPubKeysCdc := make([]cadence.Value, len(dkgPubKeys))
		for i, key := range dkgPubKeys {
			dkgPubKeysCdc[i], _ = cadence.NewString(key)
		}
		tx.AddArgument(cadence.NewArray(dkgPubKeysCdc))

		nodeIDs := make([]cadence.Value, len(ids))
		for i, id := range ids {
			nodeIDs[i], _ = cadence.NewString(id)
		}
		tx.AddArgument(cadence.NewArray(nodeIDs))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]sdkcrypto.Signer{IDTableSigner},
			false,
		)

		verifyEpochMetadata(t, b, env,
			EpochMetadata{
				counter:               startEpochCounter + 1,
				seed:                  "stillSoRandom",
				startView:             startView,
				endView:               endView,
				stakingEndView:        stakingEndView,
				totalRewards:          "0.0",
				rewardsBreakdownArray: 0,
				rewardsPaid:           false,
				collectorClusters:     nil,
				clusterQCs:            nil,
				dkgKeys:               dkgPubKeys})

		// result := executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)
		// assert.Equal(t, cadence.NewBool(false), result)

		// result = executeScriptAndCheck(t, b, templates.GenerateGetQCEnabledScript(env), nil)
		// assert.Equal(t, cadence.NewBool(false), result)
	})
}
