package test

import (
	"encoding/hex"
	"fmt"
	"math/rand"
	"strings"
	"testing"
	"time"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/crypto"
	"github.com/onflow/flow-go/module/signature"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
	"github.com/onflow/flow-emulator/adapters"
	emulator "github.com/onflow/flow-emulator/emulator"
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
)

var collectorVoteTag = signature.CollectorVoteTag

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
	_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
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
		gotEndTime := uint64(gotEndTimeCdc.(cadence.UInt64))
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
			gotEndTime := uint64(gotEndTimeCdc.(cadence.UInt64))
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
		assert.Equal(t, cadence.NewArray(dkgIDs).WithType(cadence.NewVariableSizedArrayType(cadence.StringType)), result)

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

	dkgResult := ResultSubmission{
		GroupPubKey: DKGPubKeyFixture(),
		PubKeys:     DKGPubKeysFixture(1),
		IDMapping:   map[string]int{ids[1]: 0},
	}

	t.Run("Can perform DKG actions during Epoch Setup but cannot advance until QC is complete", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), addresses[1])
		_ = tx.AddArgument(CadenceString("hello world!"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{addresses[1]},
			[]sdkcrypto.Signer{signers[1]},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), addresses[1])
		err := tx.AddArgument(dkgResult.GroupPubKeyCDC())
		require.NoError(t, err)
		err = tx.AddArgument(dkgResult.PubKeysCDC())
		require.NoError(t, err)
		err = tx.AddArgument(dkgResult.IDMappingCDC())
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
		// will not panic, but will not transition to committed phase, because only DKG (not QC voting) has completed.
		advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHCOMMIT", false)

		verifyConfigMetadata(t, b, env,
			ConfigMetadata{
				currentEpochCounter:      startEpochCounter,
				proposedEpochCounter:     startEpochCounter + 1,
				currentEpochPhase:        1, // still in setup phase
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
				counter:        startEpochCounter + 1,
				clusterQCs:     clusterQCs,
				dkgGroupPubKey: dkgResult.GroupPubKey,
				dkgPubKeys:     dkgResult.PubKeys,
				dkgIDMapping:   dkgResult.IDMapping,
			})

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
				dkgKeys:               append([]string{dkgResult.GroupPubKey}, dkgResult.PubKeys...),
			})

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
				// TODO: remove?
				//dkgKeys: finalKeyStrings,
			})

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

// TestEpochRecover ensures that the epoch recover transaction recovers the epoch as expected.
// Specifically, we execute an epoch recover transaction and confirm both scenarios are true;
//   - epoch recover that specifies unsafeAllowOverwrite = false increments the epoch counter effectively starting a new epoch.
//   - epoch recover that specifies unsafeAllowOverwrite = true overwrites the current epoch and does not increment the counter.
func TestEpochRecover(t *testing.T) {

	// Perform epoch recovery by transitioning into a new epoch (counter incremented by one)
	t.Run("Can recover the epoch with a new epoch", func(t *testing.T) {
		epochConfig := &testEpochConfig{
			startEpochCounter:    startEpochCounter,
			numEpochViews:        numEpochViews,
			numStakingViews:      numStakingViews,
			numDKGViews:          numDKGViews,
			numClusters:          numClusters,
			numEpochAccounts:     numEpochAccounts,
			randomSource:         randomSource,
			rewardIncreaseFactor: rewardIncreaseFactor,
		}
		runWithDefaultContracts(t, epochConfig, func(b emulator.Emulator, env templates.Environment, ids []string, idTableAddress flow.Address, IDTableSigner sdkcrypto.Signer, adapter *adapters.SDKAdapter) {
			advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)
			epochTimingConfigResult := executeScriptAndCheck(t, b, templates.GenerateGetEpochTimingConfigScript(env), nil)
			var (
				startView      uint64 = 100
				stakingEndView uint64 = 120
				endView        uint64 = 160
				targetDuration uint64 = numEpochViews
				epochCounter   uint64 = startEpochCounter + 1
				targetEndTime  uint64 = expectedTargetEndTime(epochTimingConfigResult, epochCounter)
			)
			args := getRecoveryTxArgs(env, ids, startView, stakingEndView, endView, targetDuration, targetEndTime, epochCounter)

			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRecoverEpochScript(env), idTableAddress)
			for _, arg := range args {
				tx.AddArgument(arg)
			}

			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				false,
			)

			advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "BLOCK", false)

			verifyEpochRecoverGovernanceTx(t, b, env, ids,
				startView,
				stakingEndView,
				endView,
				targetDuration,
				targetEndTime,
				epochCounter,
				"0.0",
				idTableAddress,
				adapter,
				args,
			)
		})
	})

	t.Run("Can recover the current epoch and overwrite the current epoch metadata", func(t *testing.T) {
		epochConfig := &testEpochConfig{
			startEpochCounter:    startEpochCounter,
			numEpochViews:        numEpochViews,
			numStakingViews:      numStakingViews,
			numDKGViews:          numDKGViews,
			numClusters:          numClusters,
			numEpochAccounts:     numEpochAccounts,
			randomSource:         randomSource,
			rewardIncreaseFactor: rewardIncreaseFactor,
		}
		runWithDefaultContracts(t, epochConfig, func(b emulator.Emulator, env templates.Environment, ids []string, idTableAddress flow.Address, IDTableSigner sdkcrypto.Signer, adapter *adapters.SDKAdapter) {
			// Advance to epoch Setup and make sure that the epoch cannot be ended
			advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)
			epochTimingConfigResult := executeScriptAndCheck(t, b, templates.GenerateGetEpochTimingConfigScript(env), nil)
			var (
				startView      uint64 = 100
				stakingEndView uint64 = 120
				endView        uint64 = 160
				targetDuration uint64 = numEpochViews
				targetEndTime  uint64 = expectedTargetEndTime(epochTimingConfigResult, startEpochCounter)
			)
			args := getRecoveryTxArgs(env, ids, startView, stakingEndView, endView, targetDuration, targetEndTime, startEpochCounter)
			// overwrite the current epoch by setting unsafe overwrite to true
			args[11] = cadence.NewBool(true)
			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRecoverEpochScript(env), idTableAddress)
			for _, arg := range args {
				tx.AddArgument(arg)
			}

			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				false,
			)

			advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "BLOCK", false)

			verifyEpochRecoverGovernanceTx(t, b, env, ids,
				startView,
				stakingEndView,
				endView,
				targetDuration,
				targetEndTime,
				startEpochCounter,
				"0.0",
				idTableAddress,
				adapter,
				args,
			)
		})
	})

	t.Run("Panics when recovering the current epoch and recover epoch counter is not equal to the current epoch counter", func(t *testing.T) {
		epochConfig := &testEpochConfig{
			startEpochCounter:    startEpochCounter,
			numEpochViews:        numEpochViews,
			numStakingViews:      numStakingViews,
			numDKGViews:          numDKGViews,
			numClusters:          numClusters,
			numEpochAccounts:     numEpochAccounts,
			randomSource:         randomSource,
			rewardIncreaseFactor: rewardIncreaseFactor,
		}
		runWithDefaultContracts(t, epochConfig, func(b emulator.Emulator, env templates.Environment, ids []string, idTableAddress flow.Address, IDTableSigner sdkcrypto.Signer, adapter *adapters.SDKAdapter) {
			epochTimingConfigResult := executeScriptAndCheck(t, b, templates.GenerateGetEpochTimingConfigScript(env), nil)
			var (
				startView      uint64 = 100
				stakingEndView uint64 = 120
				endView        uint64 = 160
				targetDuration uint64 = numEpochViews
				// invalid epoch counter when recovering the current epoch the counter should equal the current epoch counter
				epochCounter  uint64 = startEpochCounter + 1
				targetEndTime uint64 = expectedTargetEndTime(epochTimingConfigResult, epochCounter)
			)
			args := getRecoveryTxArgs(env, ids, startView, stakingEndView, endView, targetDuration, targetEndTime, epochCounter)
			// set unsafe overwrite to true
			args[len(args)-1] = cadence.NewBool(true)
			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRecoverEpochScript(env), idTableAddress)
			for _, arg := range args {
				tx.AddArgument(arg)
			}

			expectedErr := fmt.Errorf("recovery epoch counter does not equal current epoch counter")
			assertTransactionReverts(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				expectedErr,
			)
		})
	})

	t.Run("Panics when recovering a new epoch and recover epoch counter is not equal to the current epoch counter + 1", func(t *testing.T) {
		epochConfig := &testEpochConfig{
			startEpochCounter:    startEpochCounter,
			numEpochViews:        numEpochViews,
			numStakingViews:      numStakingViews,
			numDKGViews:          numDKGViews,
			numClusters:          numClusters,
			numEpochAccounts:     numEpochAccounts,
			randomSource:         randomSource,
			rewardIncreaseFactor: rewardIncreaseFactor,
		}
		runWithDefaultContracts(t, epochConfig, func(b emulator.Emulator, env templates.Environment, ids []string, idTableAddress flow.Address, IDTableSigner sdkcrypto.Signer, adapter *adapters.SDKAdapter) {
			epochTimingConfigResult := executeScriptAndCheck(t, b, templates.GenerateGetEpochTimingConfigScript(env), nil)
			var (
				startView      uint64 = 100
				stakingEndView uint64 = 120
				endView        uint64 = 160
				targetDuration uint64 = numEpochViews
				// invalid epoch counter when recovering the current epoch the counter should equal the current epoch counter
				epochCounter  uint64 = startEpochCounter
				targetEndTime uint64 = expectedTargetEndTime(epochTimingConfigResult, epochCounter)
			)
			args := getRecoveryTxArgs(env, ids, startView, stakingEndView, endView, targetDuration, targetEndTime, epochCounter)
			// avoid using the recover epoch transaction template which has sanity checks that would prevent submitting the invalid epoch counter
			code := `
				import FlowEpoch from "FlowEpoch"
				import FlowIDTableStaking from "FlowIDTableStaking"
				import FlowClusterQC from "FlowClusterQC"
				transaction(recoveryEpochCounter: UInt64,
							startView: UInt64,
							stakingEndView: UInt64,
							endView: UInt64,
							targetDuration: UInt64,
							targetEndTime: UInt64,
							clusterAssignments: [[String]],
							clusterQCVoteData: [FlowClusterQC.ClusterQCVoteData],
							dkgPubKeys: [String],
							dkgIdMapping: {String: Int},
							nodeIDs: [String],
							unsafeAllowOverwrite: Bool) {

					prepare(signer: auth(BorrowValue) &Account) {
						let epochAdmin = signer.storage.borrow<&FlowEpoch.Admin>(from: FlowEpoch.adminStoragePath)
							?? panic("Could not borrow epoch admin from storage path")

						epochAdmin.recoverNewEpoch(
								recoveryEpochCounter: recoveryEpochCounter,
								startView: startView,
								stakingEndView: stakingEndView,
								endView: endView,
								targetDuration: targetDuration,
								targetEndTime: targetEndTime,
								clusterAssignments: clusterAssignments,
								clusterQCVoteData: clusterQCVoteData,
								dkgPubKeys: dkgPubKeys,
								dkgIdMapping: dkgIdMapping,
								nodeIDs: nodeIDs
							)
					}
				}
			`
			tx := createTxWithTemplateAndAuthorizer(b, []byte(templates.ReplaceAddresses(code, env)), idTableAddress)
			for _, arg := range args {
				tx.AddArgument(arg)
			}

			expectedErr := fmt.Errorf("recovery epoch counter should equal current epoch counter + 1")
			assertTransactionReverts(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				expectedErr,
			)
		})
	})

	t.Run("Recover epoch transaction panics when recovery epoch counter is less than currentCounter and unsafeAllowOverwrite is false", func(t *testing.T) {
		epochConfig := &testEpochConfig{
			startEpochCounter:    1,
			numEpochViews:        numEpochViews,
			numStakingViews:      numStakingViews,
			numDKGViews:          numDKGViews,
			numClusters:          numClusters,
			numEpochAccounts:     numEpochAccounts,
			randomSource:         randomSource,
			rewardIncreaseFactor: rewardIncreaseFactor,
		}
		runWithDefaultContracts(t, epochConfig, func(b emulator.Emulator, env templates.Environment, ids []string, idTableAddress flow.Address, IDTableSigner sdkcrypto.Signer, adapter *adapters.SDKAdapter) {
			epochTimingConfigResult := executeScriptAndCheck(t, b, templates.GenerateGetEpochTimingConfigScript(env), nil)
			var (
				startView      uint64 = 100
				stakingEndView uint64 = 120
				endView        uint64 = 160
				targetDuration uint64 = numEpochViews
				// invalid epoch counter less than current epoch counter 1
				epochCounter  uint64 = 0
				targetEndTime uint64 = expectedTargetEndTime(epochTimingConfigResult, epochCounter)
			)
			args := getRecoveryTxArgs(env, ids, startView, stakingEndView, endView, targetDuration, targetEndTime, epochCounter)
			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRecoverEpochScript(env), idTableAddress)
			for _, arg := range args {
				tx.AddArgument(arg)
			}

			expectedErr := fmt.Errorf("cannot overwrite existing epoch with safety flag specified")
			assertTransactionReverts(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				expectedErr,
			)
		})
	})

	t.Run("Recover epoch transaction panics when recovery epoch counter greater than proposedCounter and unsafeAllowOverwrite is false", func(t *testing.T) {
		epochConfig := &testEpochConfig{
			startEpochCounter:    startEpochCounter,
			numEpochViews:        numEpochViews,
			numStakingViews:      numStakingViews,
			numDKGViews:          numDKGViews,
			numClusters:          numClusters,
			numEpochAccounts:     numEpochAccounts,
			randomSource:         randomSource,
			rewardIncreaseFactor: rewardIncreaseFactor,
		}
		runWithDefaultContracts(t, epochConfig, func(b emulator.Emulator, env templates.Environment, ids []string, idTableAddress flow.Address, IDTableSigner sdkcrypto.Signer, adapter *adapters.SDKAdapter) {
			epochTimingConfigResult := executeScriptAndCheck(t, b, templates.GenerateGetEpochTimingConfigScript(env), nil)
			var (
				startView      uint64 = 100
				stakingEndView uint64 = 120
				endView        uint64 = 160
				targetDuration uint64 = numEpochViews
				// invalid epoch counter greater than proposed epoch counter
				epochCounter  uint64 = startEpochCounter + 2
				targetEndTime uint64 = expectedTargetEndTime(epochTimingConfigResult, epochCounter)
			)
			args := getRecoveryTxArgs(env, ids, startView, stakingEndView, endView, targetDuration, targetEndTime, epochCounter)
			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRecoverEpochScript(env), idTableAddress)
			for _, arg := range args {
				tx.AddArgument(arg)
			}

			expectedErr := fmt.Errorf("cannot overwrite existing epoch with safety flag specified")
			assertTransactionReverts(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				expectedErr,
			)
		})
	})

	t.Run("Can recover the epoch during the staking auction with automatic rewards enabled", func(t *testing.T) {
		epochConfig := &testEpochConfig{
			startEpochCounter:    startEpochCounter,
			numEpochViews:        numEpochViews,
			numStakingViews:      numStakingViews,
			numDKGViews:          numDKGViews,
			numClusters:          numClusters,
			numEpochAccounts:     numEpochAccounts,
			randomSource:         randomSource,
			rewardIncreaseFactor: rewardIncreaseFactor,
		}
		runWithDefaultContracts(t, epochConfig, func(b emulator.Emulator, env templates.Environment, ids []string, idTableAddress flow.Address, IDTableSigner sdkcrypto.Signer, adapter *adapters.SDKAdapter) {
			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochSetAutomaticRewardsScript(env), idTableAddress)
			tx.AddArgument(cadence.NewBool(true))
			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				false,
			)

			advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "EPOCHSETUP", false)
			epochTimingConfigResult := executeScriptAndCheck(t, b, templates.GenerateGetEpochTimingConfigScript(env), nil)
			var (
				startView      uint64 = 100
				stakingEndView uint64 = 120
				endView        uint64 = 160
				targetDuration uint64 = numEpochViews
				epochCounter   uint64 = startEpochCounter + 1
				targetEndTime  uint64 = expectedTargetEndTime(epochTimingConfigResult, epochCounter)
			)
			args := getRecoveryTxArgs(env, ids, startView, stakingEndView, endView, targetDuration, targetEndTime, epochCounter)

			tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateRecoverEpochScript(env), idTableAddress)
			for _, arg := range args {
				tx.AddArgument(arg)
			}

			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				false,
			)

			advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "BLOCK", false)

			verifyEpochRecoverGovernanceTx(t, b, env, ids,
				startView,
				stakingEndView,
				endView,
				targetDuration,
				targetEndTime,
				epochCounter,
				// The calculation of the total rewards should have happened
				// because automatic rewards are enabled
				// (total supply + current payount amount - bonus tokens) * reward increase factor
				// (7000000000 + 1250000 - 0) * 0.00093871 = 6,571,204.6775
				"6572143.38750000",
				idTableAddress,
				adapter,
				args,
			)

			args = getRecoveryTxArgs(env, ids, startView, stakingEndView, endView, targetDuration, targetEndTime, epochCounter+1)
			tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateRecoverEpochScript(env), idTableAddress)
			for _, arg := range args {
				tx.AddArgument(arg)
			}

			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				false,
			)

			advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "BLOCK", false)

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
					total:      "6572143.38750000",
					fromFees:   "0.0",
					minted:     "6572143.38750000",
					feesBurned: "0.01500000"})

			result := executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[0]))})
			assertEqual(t, CadenceUFix64("1314428.67450000"), result)

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
			assertEqual(t, CadenceUFix64("1314428.67450000"), result)

			// overwrite current epoch with a recover transaction, rewards should not be paid out
			args = getRecoveryTxArgs(env, ids, startView, stakingEndView, endView, targetDuration, targetEndTime, epochCounter+1)
			// set unsafe overwrite to true
			args[len(args)-1] = cadence.NewBool(true)
			tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateRecoverEpochScript(env), idTableAddress)
			for _, arg := range args {
				tx.AddArgument(arg)
			}

			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				false,
			)

			advanceView(t, b, env, idTableAddress, IDTableSigner, 1, "BLOCK", false)

			tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEpochPayRewardsScript(env), idTableAddress)

			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]sdkcrypto.Signer{IDTableSigner},
				false,
			)

			// The nodes rewards should not have increased
			result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[0]))})
			assertEqual(t, CadenceUFix64("1314428.67450000"), result)
		})
	})
}

func getRecoveryTxArgs(
	env templates.Environment,
	nodeIds []string,
	startView uint64,
	stakingEndView uint64,
	endView uint64,
	targetDuration uint64,
	targetEndTime uint64,
	epochCounter uint64,
) []cadence.Value {
	collectorClusters := make([]cadence.Value, 3)
	collectorClusters[0] = cadence.NewArray([]cadence.Value{CadenceString("node_1"), CadenceString("node_2"), CadenceString("node_3")})
	collectorClusters[1] = cadence.NewArray([]cadence.Value{CadenceString("node_4"), CadenceString("node_5"), CadenceString("node_6")})
	collectorClusters[2] = cadence.NewArray([]cadence.Value{CadenceString("node_7"), CadenceString("node_8"), CadenceString("node_9")})

	dkgPubKeys := []string{"pubkey_1"}
	dkgPubKeysCdc := make([]cadence.Value, len(dkgPubKeys))
	for i, key := range dkgPubKeys {
		dkgPubKeysCdc[i], _ = cadence.NewString(key)
	}

	nodeIDs := make([]cadence.Value, len(nodeIds))
	for i, id := range nodeIds {
		nodeIDs[i], _ = cadence.NewString(id)
	}
	clusterQcVoteData := convertClusterQcsCdc(env, collectorClusters)
	return []cadence.Value{
		cadence.NewUInt64(epochCounter),
		cadence.NewUInt64(startView),
		cadence.NewUInt64(stakingEndView),
		cadence.NewUInt64(endView),
		cadence.NewUInt64(targetDuration),
		cadence.NewUInt64(targetEndTime),
		cadence.NewArray(collectorClusters),
		cadence.NewArray(clusterQcVoteData),
		cadence.NewArray(dkgPubKeysCdc),
		cadence.NewDictionary([]cadence.KeyValuePair{{
			Key:   cadence.String(nodeIds[0]),
			Value: cadence.NewInt(0),
		}}),
		cadence.NewArray(nodeIDs),
		cadence.NewBool(false), // recover EFM with a new epoch, set unsafeAllowOverwrite to false
	}
}

// verifyEpochRecoverGovernanceTx ensures that epoch metadata is updated with
// the provided info and an corresponding epoch recover event was emitted with the same info.
func verifyEpochRecoverGovernanceTx(
	t *testing.T,
	b emulator.Emulator,
	env templates.Environment,
	nodeIds []string,
	startView uint64,
	stakingEndView uint64,
	endView uint64,
	targetDuration uint64,
	targetEndTime uint64,
	epochCounter uint64,
	totalRewards string,
	idTableAddress flow.Address,
	adapter *adapters.SDKAdapter,
	args []cadence.Value,
) {
	dkgPubKeys := make([]string, len(args[8].(cadence.Array).Values))
	dkgIdMappingKVP := make([]cadence.KeyValuePair, len(dkgPubKeys))
	for i, _ := range dkgPubKeys {
		dkgIdMappingKVP[i] = cadence.KeyValuePair{
			Key:   cadence.String(fmt.Sprintf("node_%d", i)),
			Value: cadence.NewInt(i),
		}
	}
	for i, dkgKeyCdc := range args[8].(cadence.Array).Values {
		// strip `"` characters because the Cadence fmt.Stringer implementation adds them.
		dkgPubKeys[i] = strings.ReplaceAll(dkgKeyCdc.String(), `"`, "")
	}
	// seed is not manually set when recovering the epoch, it is randomly generated
	metadataFields := getEpochMetadata(t, b, env, cadence.NewUInt64(epochCounter))
	seed := strings.ReplaceAll(metadataFields["seed"].String(), `"`, "")
	expectedMetadata := EpochMetadata{
		counter:               epochCounter,
		seed:                  seed,
		startView:             startView,
		endView:               endView,
		stakingEndView:        stakingEndView,
		totalRewards:          totalRewards,
		rewardsBreakdownArray: 0,
		rewardsPaid:           false,
		collectorClusters:     nil,
		clusterQCs:            nil,
		dkgKeys:               dkgPubKeys,
	}
	verifyEpochMetadata(t, b, env, expectedMetadata)
	assertEqual(t, getCurrentEpochCounter(t, b, env), cadence.NewUInt64(epochCounter))
	expectedRecoverEvent := EpochRecover{
		counter:            epochCounter,
		nodeInfoLength:     len(nodeIds),
		firstView:          startView,
		finalView:          endView,
		collectorClusters:  args[6].(cadence.Array).Values,
		randomSource:       seed,
		dkgPhase1FinalView: stakingEndView + numDKGViews,
		dkgPhase2FinalView: stakingEndView + (2 * numDKGViews),
		dkgPhase3FinalView: stakingEndView + (3 * numDKGViews),
		targetDuration:     targetDuration,
		targetEndTime:      targetEndTime,
		numberClusterQCs:   len(args[6].(cadence.Array).Values),
		dkgPubKeys:         dkgPubKeys,
		dkgIdMapping:       cadence.NewDictionary(dkgIdMappingKVP),
	}
	verifyEpochRecover(t, adapter, idTableAddress, expectedRecoverEvent)
}
