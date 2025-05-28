package test

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"testing"

	"github.com/onflow/cadence"
	"github.com/onflow/cadence/common"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/cadence/interpreter"
	"github.com/onflow/flow-emulator/adapters"
	emulator "github.com/onflow/flow-emulator/emulator"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	sdkcrypto "github.com/onflow/flow-go-sdk/crypto"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

/*
*
* This file includes many definitions for functions and structs that are valuable
* for using and interacting with the epoch smart contracts
*
 */

// Used to verify the values of the clusters in the smart contract
type Cluster struct {
	index       uint16
	totalWeight uint64
	size        uint16
}

// Used to verify epoch metadata in tests
type EpochMetadata struct {
	counter                  uint64
	seed                     string
	startView                uint64
	endView                  uint64
	stakingEndView           uint64
	totalRewards             string
	rewardsBreakdownArrayLen int
	rewardsPaid              bool
	collectorClusters        []Cluster
	clusterQCs               [][]string
	dkgKeys                  []string
}

// Used to verify the configurable Epoch metadata in tests
type ConfigMetadata struct {
	currentEpochCounter      uint64
	proposedEpochCounter     uint64
	currentEpochPhase        uint8
	numViewsInEpoch          uint64
	numViewsInStakingAuction uint64
	rewardPercentage         string
	numViewsInDKGPhase       uint64
	numCollectorClusters     uint16
}

// EpochTimingConfig is used to verify timing config stored on-chain.
type EpochTimingConfig struct {
	duration     uint64
	refCounter   uint64
	refTimestamp uint64
}

// Used to verify the EpochStart event fields in tests
type EpochStart struct {
	counter        uint64
	firstView      uint64
	stakingEndView uint64
	finalView      uint64
	totalStaked    string
	totalSupply    string
	rewards        string
}

type EpochStartEvent flow.Event

func (evt EpochStartEvent) Counter() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "counter").(cadence.UInt64)
}

func (evt EpochStartEvent) firstView() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "firstView").(cadence.UInt64)
}

func (evt EpochStartEvent) stakingEndView() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "stakingAuctionEndView").(cadence.UInt64)
}

func (evt EpochStartEvent) finalView() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "finalView").(cadence.UInt64)
}

func (evt EpochStartEvent) totalStaked() cadence.UFix64 {
	return cadence.SearchFieldByName(evt.Value, "totalStaked").(cadence.UFix64)
}

func (evt EpochStartEvent) totalSupply() cadence.UFix64 {
	return cadence.SearchFieldByName(evt.Value, "totalFlowSupply").(cadence.UFix64)
}

func (evt EpochStartEvent) rewards() cadence.UFix64 {
	return cadence.SearchFieldByName(evt.Value, "totalRewards").(cadence.UFix64)
}

// Used to verify the EpochSetup event fields in tests
type EpochSetup struct {
	counter            uint64
	nodeInfoLength     int
	firstView          uint64
	finalView          uint64
	collectorClusters  []Cluster
	randomSource       string
	dkgPhase1FinalView uint64
	dkgPhase2FinalView uint64
	dkgPhase3FinalView uint64
	targetDuration     uint64
	targetEndTime      uint64
}

// Used to verify the EpochCommit event fields in tests
type EpochCommit struct {
	counter        uint64
	clusterQCs     [][]string
	dkgGroupPubKey string
	dkgPubKeys     []string
	dkgIDMapping   map[string]int
}

// EpochRecover used to verify EpochRecover event fields in tests.
type EpochRecover struct {
	counter            uint64
	nodeInfoLength     int
	firstView          uint64
	finalView          uint64
	collectorClusters  []cadence.Value
	randomSource       string
	dkgPhase1FinalView uint64
	dkgPhase2FinalView uint64
	dkgPhase3FinalView uint64
	targetDuration     uint64
	targetEndTime      uint64
	numberClusterQCs   int
	dkgPubKeys         []string
	dkgGroupKey        string
	dkgIdMapping       cadence.Dictionary
}

type EpochRecoverEvent flow.Event

// Counter returns counter field in EpochRecover event.
func (evt EpochRecoverEvent) Counter() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "counter").(cadence.UInt64)
}

// NodeInfo returns nodeInfo field in EpochRecover event.
func (evt EpochRecoverEvent) NodeInfo() cadence.Array {
	return cadence.SearchFieldByName(evt.Value, "nodeInfo").(cadence.Array)
}

// FirstView returns firstView field in EpochRecover event.
func (evt EpochRecoverEvent) FirstView() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "firstView").(cadence.UInt64)
}

// FinalView returns finalView field in EpochRecover event.
func (evt EpochRecoverEvent) FinalView() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "finalView").(cadence.UInt64)
}

// CollectorClusters returns clusterAssignments field in EpochRecover event.
func (evt EpochRecoverEvent) CollectorClusters() cadence.Array {
	return cadence.SearchFieldByName(evt.Value, "clusterAssignments").(cadence.Array)
}

// RandomSource returns randomSource field in EpochRecover event.
func (evt EpochRecoverEvent) RandomSource() cadence.String {
	return cadence.SearchFieldByName(evt.Value, "randomSource").(cadence.String)
}

// DKGFinalViews returns dkgFinalViews field in EpochRecover event.
func (evt EpochRecoverEvent) DKGFinalViews() (cadence.UInt64, cadence.UInt64, cadence.UInt64) {
	return cadence.SearchFieldByName(evt.Value, "DKGPhase1FinalView").(cadence.UInt64),
		cadence.SearchFieldByName(evt.Value, "DKGPhase2FinalView").(cadence.UInt64),
		cadence.SearchFieldByName(evt.Value, "DKGPhase3FinalView").(cadence.UInt64)
}

// TargetDuration returns targetDuration field in EpochRecover event.
func (evt EpochRecoverEvent) TargetDuration() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "targetDuration").(cadence.UInt64)
}

// TargetEndTime returns targetEndTime field in EpochRecover event.
func (evt EpochRecoverEvent) TargetEndTime() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "targetEndTime").(cadence.UInt64)
}

// ClusterQCVoteData returns clusterQCVoteData field in EpochRecover event.
func (evt EpochRecoverEvent) ClusterQCVoteData() cadence.Array {
	return cadence.SearchFieldByName(evt.Value, "clusterQCVoteData").(cadence.Array)
}

// DKGPubKeys returns dkgPubKeys field in EpochRecover event.
func (evt EpochRecoverEvent) DKGPubKeys() cadence.Array {
	return cadence.SearchFieldByName(evt.Value, "dkgPubKeys").(cadence.Array)
}

// DKGGroupKey returns dkgGroupKey field in EpochRecover event.
func (evt EpochRecoverEvent) DKGGroupKey() cadence.Array {
	return cadence.SearchFieldByName(evt.Value, "dkgGroupKey").(cadence.Array)
}

// Go event definitions for the epoch events
// Can be used with the SDK to retrieve and parse epoch events

type EpochSetupEvent flow.Event

func (evt EpochSetupEvent) Counter() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "counter").(cadence.UInt64)
}

func (evt EpochSetupEvent) NodeInfo() cadence.Array {
	return cadence.SearchFieldByName(evt.Value, "nodeInfo").(cadence.Array)
}

func (evt EpochSetupEvent) firstView() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "firstView").(cadence.UInt64)
}

func (evt EpochSetupEvent) finalView() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "finalView").(cadence.UInt64)
}

func (evt EpochSetupEvent) collectorClusters() cadence.Array {
	return cadence.SearchFieldByName(evt.Value, "collectorClusters").(cadence.Array)
}

func (evt EpochSetupEvent) randomSource() cadence.String {
	return cadence.SearchFieldByName(evt.Value, "randomSource").(cadence.String)
}

func (evt EpochSetupEvent) dkgFinalViews() (cadence.UInt64, cadence.UInt64, cadence.UInt64) {
	fields := cadence.FieldsMappedByName(evt.Value)
	return fields["DKGPhase1FinalView"].(cadence.UInt64), fields["DKGPhase2FinalView"].(cadence.UInt64), fields["DKGPhase3FinalView"].(cadence.UInt64)
}

func (evt EpochSetupEvent) targetDuration() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "targetDuration").(cadence.UInt64)
}

func (evt EpochSetupEvent) targetEndTime() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "targetEndTime").(cadence.UInt64)
}

type EpochCommitEvent flow.Event

func (evt EpochCommitEvent) Counter() cadence.UInt64 {
	return cadence.SearchFieldByName(evt.Value, "counter").(cadence.UInt64)
}

func (evt EpochCommitEvent) clusterQCs() cadence.Array {
	return cadence.SearchFieldByName(evt.Value, "clusterQCs").(cadence.Array)
}

func (evt EpochCommitEvent) dkgGroupPubKey() cadence.String {
	return cadence.SearchFieldByName(evt.Value, "dkgGroupKey").(cadence.String)
}

func (evt EpochCommitEvent) dkgPubKeys() cadence.Array {
	return cadence.SearchFieldByName(evt.Value, "dkgPubKeys").(cadence.Array)
}

func (evt EpochCommitEvent) dkgIDMapping() cadence.Dictionary {
	return cadence.SearchFieldByName(evt.Value, "dkgIdMapping").(cadence.Dictionary)
}

// / Deploys the Quroum Certificate and Distributed Key Generation contracts to the provided account
// /
func deployQCDKGContract(
	t *testing.T,
	b emulator.Emulator,
	idTableAddress flow.Address,
	IDTableSigner crypto.Signer,
	env templates.Environment) {

	QCCode := contracts.FlowQC()
	QCByteCode := bytesToCadenceArray(QCCode)

	DKGCode := contracts.FlowDKG()
	DKGByteCode := bytesToCadenceArray(DKGCode)

	qcName, _ := cadence.NewString("FlowClusterQC")
	dkgName, _ := cadence.NewString("FlowDKG")

	// Deploy the QC and DKG contracts
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDeployQCDKGScript(env), idTableAddress).
		AddRawArgument(jsoncdc.MustEncode(qcName)).
		AddRawArgument(jsoncdc.MustEncode(QCByteCode)).
		AddRawArgument(jsoncdc.MustEncode(dkgName)).
		AddRawArgument(jsoncdc.MustEncode(DKGByteCode))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)
}

// / Deploys the epoch lifecycle contract to the provided account with all the specified init values
// / uses empty clusters, qcs, and dkg keys for now
func deployEpochContract(
	t *testing.T,
	b emulator.Emulator,
	idTableAddress flow.Address,
	IDTableSigner crypto.Signer,
	feesAddr flow.Address,
	env templates.Environment,
	epochCounter, epochViews, stakingViews, dkgViews, numClusters uint64,
	randomSource, rewardAPY string) {

	EpochCode := contracts.FlowEpoch(env)
	EpochByteCode := bytesToCadenceArray(EpochCode)

	epochName, _ := cadence.NewString("FlowEpoch")
	cadRandomSource, _ := cadence.NewString(randomSource)

	// Deploy the Epoch contract
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDeployEpochScript(env), idTableAddress).
		AddRawArgument(jsoncdc.MustEncode(epochName)).
		AddRawArgument(jsoncdc.MustEncode(EpochByteCode))

	_ = tx.AddArgument(cadence.NewUInt64(epochCounter))
	_ = tx.AddArgument(cadence.NewUInt64(epochViews))
	_ = tx.AddArgument(cadence.NewUInt64(stakingViews))
	_ = tx.AddArgument(cadence.NewUInt64(dkgViews))
	_ = tx.AddArgument(cadence.NewUInt16(uint16(numClusters)))
	_ = tx.AddArgument(CadenceUFix64(rewardAPY))
	_ = tx.AddArgument(cadRandomSource)
	_ = tx.AddArgument(cadence.NewArray([]cadence.Value{}))
	_ = tx.AddArgument(cadence.NewArray([]cadence.Value{}))
	_ = tx.AddArgument(cadence.NewArray([]cadence.Value{}))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)
}

// / Deploys the staking contract, qc, dkg, and epoch contracts
func initializeAllEpochContracts(
	t *testing.T,
	b emulator.Emulator,
	IDTableAccountKey *flow.AccountKey,
	IDTableSigner crypto.Signer,
	env *templates.Environment,
	epochCounter, epochViews, stakingViews, dkgViews, numClusters uint64,
	randomSource, rewardsAPY string) (flow.Address, uint64) {

	idTableAddress, feesAddress := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, env, true, []uint64{10, 10, 10, 10, 10})
	env.IDTableAddress = idTableAddress.Hex()
	env.FlowFeesAddress = feesAddress.Hex()
	env.QuorumCertificateAddress = idTableAddress.String()
	env.DkgAddress = idTableAddress.String()
	env.EpochAddress = idTableAddress.String()
	env.IDTableAddress = idTableAddress.String()

	deployQCDKGContract(t, b, idTableAddress, IDTableSigner, *env)
	deployEpochContract(t, b, idTableAddress, IDTableSigner, feesAddress, *env, epochCounter, epochViews, stakingViews, dkgViews, numClusters, randomSource, rewardsAPY)

	result := executeScriptAndCheck(t, b, templates.GenerateGetCurrentViewScript(*env), nil)
	startView := uint64(result.(cadence.UInt64))

	return idTableAddress, startView
}

// / Attempts to advance the epoch to the specified phase
// / "EPOCHSETUP", "EPOCHCOMMIT", or "ENDEPOCH",
// / "BLOCK" allows the contract to just advance a block
func advanceView(
	t *testing.T,
	b emulator.Emulator,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	numBlocks int,
	phase string,
	shouldFail bool) {

	cadencePhase, _ := cadence.NewString(phase)

	for i := 0; i < numBlocks; i++ {
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateAdvanceViewScript(env), authorizer)
		_ = tx.AddArgument(cadencePhase)
		signAndSubmit(
			t, b, tx,
			[]flow.Address{authorizer},
			[]crypto.Signer{signer},
			shouldFail,
		)
	}
}

func registerNodeWithSetupAccount(t *testing.T,
	b emulator.Emulator,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	nodeID, networkingAddress, networkingKey, stakingKey, stakingKeyPOP string,
	amount, tokensCommitted interpreter.UFix64Value,
	role uint8,
	publicKey *flow.AccountKey,
	shouldFail bool,
) (
	newTokensCommitted interpreter.UFix64Value,
) {

	publicKeys := make([]cadence.Value, 1)
	cdcPublicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(publicKey)
	publicKeys[0] = cdcPublicKey
	require.NoError(t, err)

	cadencePublicKeys := cadence.NewArray(publicKeys)

	cadenceID, _ := cadence.NewString(nodeID)
	cadenceNetAddr, _ := cadence.NewString(networkingAddress)
	cadenceNetKey, _ := cadence.NewString(networkingKey)
	cadenceStakeKey, _ := cadence.NewString(stakingKey)
	cadenceStakeKeyPOP, _ := cadence.NewString(stakingKeyPOP)

	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateEpochRegisterNodeScript(env),
		authorizer)

	_ = tx.AddArgument(cadenceID)
	_ = tx.AddArgument(cadence.NewUInt8(role))
	_ = tx.AddArgument(cadenceNetAddr)
	_ = tx.AddArgument(cadenceNetKey)
	_ = tx.AddArgument(cadenceStakeKey)
	_ = tx.AddArgument(cadenceStakeKeyPOP)
	tokenAmount, err := cadence.NewUFix64(amount.String())
	require.NoError(t, err)
	_ = tx.AddArgument(tokenAmount)

	tx.AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{authorizer},
		[]crypto.Signer{signer},
		shouldFail,
	)

	if !shouldFail {
		newTokensCommitted = tokensCommitted.Plus(stubInterpreter(), amount, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
	}

	return
}

// / Registers the specified number of nodes for staking and qc/dkg in the same transaction
// / creates a secondary account for the nodes who have the qc or dkg resources
// / with the same keys as the first account
func registerNodesForEpochs(
	t *testing.T,
	b emulator.Emulator,
	env templates.Environment,
	authorizers []flow.Address,
	signers []crypto.Signer,
	publicKeys []*flow.AccountKey,
	ids []string,
	stakingKeys []string,
	stakingKeysPOPs []string,
	networkingkeys []string) {

	if len(authorizers) != len(signers) ||
		len(authorizers) != len(ids) {
		t.Fail()
	}

	var amountToCommit interpreter.UFix64Value = 135000000000000
	var committed interpreter.UFix64Value = 0

	i := 0
	for _, authorizer := range authorizers {

		registerNodeWithSetupAccount(t, b, env,
			authorizer,
			signers[i],
			ids[i],
			fmt.Sprintf("%0128d", i),
			networkingkeys[i],
			stakingKeys[i],
			stakingKeysPOPs[i],
			amountToCommit,
			committed,
			uint8((i%5)+1),
			publicKeys[i],
			false)

		i++
	}
}

// Verifies that the clusters provided are the same as the expected clusters
func verifyClusters(
	t *testing.T,
	expectedClusters []Cluster,
	actualClusters []cadence.Value) {

	i := 0

	// Iterate through all the clusters and make sure their index, weight, and size is correct
	for _, expectedCluster := range expectedClusters {

		found := false

		for _, actualCluster := range actualClusters {
			cluster := actualCluster.(cadence.Struct)
			clusterFields := cadence.FieldsMappedByName(cluster)

			totalWeight := clusterFields["totalWeight"]
			if cadence.NewUInt64(expectedCluster.totalWeight) == totalWeight {
				found = true
				assertEqual(t, cadence.NewUInt64(expectedCluster.totalWeight), totalWeight)
				size := len(clusterFields["nodeWeights"].(cadence.Dictionary).Pairs)
				assertEqual(t, cadence.NewUInt16(expectedCluster.size), cadence.NewUInt16(uint16(size)))
			}
		}

		assertEqual(t, true, found)

		i = i + 1
	}

}

// Verifies that the cluster quorum certificates are equal to the provided expected values
func verifyClusterQCs(
	t *testing.T,
	expectedQCs [][]string,
	actualQCs []cadence.Value) {

	if expectedQCs == nil {
		assert.Empty(t, actualQCs)
	} else {
		i := 0
		for _, qc := range actualQCs {
			found := false
			qcStructFields := cadence.FieldsMappedByName(qc.(cadence.Struct))
			qcStructSignatures := qcStructFields["voteSignatures"].(cadence.Array).Values
			qcStructMessage := qcStructFields["voteMessage"].(cadence.String)
			qcVoterIDs := qcStructFields["voterIDs"].(cadence.Array).Values

			assertEqual(t, len(qcVoterIDs), len(qcStructSignatures))

			j := 0
			// Verify that each element is correct across the cluster
			for _, signature := range qcStructSignatures {
				for _, qc := range expectedQCs {
					cadenceSig, _ := cadence.NewString(qc[0])
					if cadenceSig == signature {
						found = true
						assertEqual(t, cadenceSig, signature)
						cadenceSig, _ = cadence.NewString(qc[1])
						assertEqual(t, cadenceSig, qcStructMessage)
					}
				}
				j = j + 1
			}

			assertEqual(t, true, found)

			i = i + 1
		}
	}
}

// verifyEpochMetadata verifies that the epoch metadata stored in the FlowEpoch smart contract
// is equal to the input expectedMetadata.
func verifyEpochMetadata(
	t *testing.T,
	b emulator.Emulator,
	env templates.Environment,
	expectedMetadata EpochMetadata) {

	metadataFields := getEpochMetadata(t, b, env, cadence.UInt64(expectedMetadata.counter))
	counter := metadataFields["counter"]
	assertEqual(t, cadence.NewUInt64(expectedMetadata.counter), counter)

	if len(expectedMetadata.seed) != 0 {
		seed := metadataFields["seed"]
		cadenceSeed, _ := cadence.NewString(expectedMetadata.seed)
		assertEqual(t, cadenceSeed, seed)
	}

	startView := metadataFields["startView"]
	assertEqual(t, cadence.NewUInt64(expectedMetadata.startView), startView)

	endView := metadataFields["endView"]
	assertEqual(t, cadence.NewUInt64(expectedMetadata.endView), endView)
	stakingEndView := metadataFields["stakingEndView"]
	assertEqual(t, cadence.NewUInt64(expectedMetadata.stakingEndView), stakingEndView)

	totalRewards := metadataFields["totalRewards"]
	assertEqual(t, CadenceUFix64(expectedMetadata.totalRewards), totalRewards)

	// NOTE: this only validates if the rewardAmounts array is empty.
	// Non-empty rewardAmounts arrays are not checked at all!
	rewardsArray := metadataFields["rewardAmounts"].(cadence.Array).Values
	if expectedMetadata.rewardsBreakdownArrayLen == 0 {
		assertEqual(t, len(rewardsArray), 0)
	}

	rewardsPaid := metadataFields["rewardsPaid"]
	assertEqual(t, cadence.NewBool(expectedMetadata.rewardsPaid), rewardsPaid)

	if expectedMetadata.collectorClusters != nil {
		clusters := metadataFields["collectorClusters"].(cadence.Array).Values

		verifyClusters(t, expectedMetadata.collectorClusters, clusters)
	}

	clusterQCs := metadataFields["clusterQCs"].(cadence.Array).Values
	verifyClusterQCs(t, expectedMetadata.clusterQCs, clusterQCs)

	dkgKeys := metadataFields["dkgKeys"].(cadence.Array).Values
	if expectedMetadata.dkgKeys == nil {
		assert.Empty(t, dkgKeys)
	} else {
		for i, key := range dkgKeys {
			cadenceKey, _ := cadence.NewString(expectedMetadata.dkgKeys[i])
			// Verify that each key is correct
			assertEqual(t, cadenceKey, key)
		}
	}
}

// verifyEpochTimingConfig verifies that the epoch timing config on-chain matches the expected value.
// For the reference timestamp, we allow a delta of 30s.
func verifyEpochTimingConfig(
	t *testing.T,
	b emulator.Emulator,
	env templates.Environment,
	expectedConfig EpochTimingConfig,
) {

	result := executeScriptAndCheck(t, b, templates.GenerateGetEpochTimingConfigScript(env), nil)
	timingConfigFields := cadence.FieldsMappedByName(result.(cadence.Struct))

	// A default epoch timing config should be set in the constructor
	assertEqual(t, cadence.NewUInt64(expectedConfig.duration), timingConfigFields["duration"])
	assertEqual(t, cadence.NewUInt64(expectedConfig.refCounter), timingConfigFields["refCounter"])
	assert.InDelta(t, expectedConfig.refTimestamp, uint64(timingConfigFields["refTimestamp"].(cadence.UInt64)), 30)
}

// Verifies that the configurable epoch metadata is equal to the provided values
func verifyConfigMetadata(
	t *testing.T,
	b emulator.Emulator,
	env templates.Environment,
	expectedMetadata ConfigMetadata) {

	result := executeScriptAndCheck(t, b, templates.GenerateGetCurrentEpochCounterScript(env), nil)
	assertEqual(t, cadence.NewUInt64(expectedMetadata.currentEpochCounter), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetProposedEpochCounterScript(env), nil)
	assertEqual(t, cadence.NewUInt64(expectedMetadata.proposedEpochCounter), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetEpochConfigMetadataScript(env), nil)
	metadataFields := cadence.FieldsMappedByName(result.(cadence.Struct))

	assertEqual(t, cadence.NewUInt64(expectedMetadata.numViewsInEpoch), metadataFields["numViewsInEpoch"])
	assertEqual(t, cadence.NewUInt64(expectedMetadata.numViewsInStakingAuction), metadataFields["numViewsInStakingAuction"])
	assertEqual(t, cadence.NewUInt64(expectedMetadata.numViewsInDKGPhase), metadataFields["numViewsInDKGPhase"])

	clusters := metadataFields["numCollectorClusters"]
	assertEqual(t, cadence.NewUInt16(expectedMetadata.numCollectorClusters), clusters)

	apy := metadataFields["FLOWsupplyIncreasePercentage"]
	assertEqual(t, CadenceUFix64(expectedMetadata.rewardPercentage), apy)

	result = executeScriptAndCheck(t, b, templates.GenerateGetEpochPhaseScript(env), nil)
	assertEqual(t, cadence.NewUInt8(expectedMetadata.currentEpochPhase), result)
}

// Verifies that the epoch start event values are equal to the provided expected values
func verifyEpochStart(
	t *testing.T,
	b emulator.Emulator,
	adapter *adapters.SDKAdapter,
	epochAddress flow.Address,
	expectedStart EpochStart) {

	var emittedEvent EpochStartEvent

	results, _ := adapter.GetEventsForHeightRange(context.Background(), "A."+epochAddress.String()+".FlowEpoch.EpochStart", 0, 1000)
	for _, result := range results {
		for _, event := range result.Events {
			if event.Type == "A."+epochAddress.String()+".FlowEpoch.EpochStart" {
				emittedEvent = EpochStartEvent(event)
				break
			}
		}
	}

	// counter
	assertEqual(t, cadence.NewUInt64(expectedStart.counter), emittedEvent.Counter())

	// views
	assertEqual(t, cadence.NewUInt64(expectedStart.firstView), emittedEvent.firstView())
	assertEqual(t, cadence.NewUInt64(expectedStart.stakingEndView), emittedEvent.stakingEndView())
	assertEqual(t, cadence.NewUInt64(expectedStart.finalView), emittedEvent.finalView())

	// FLOW amounts
	assertEqual(t, CadenceUFix64(expectedStart.totalStaked), emittedEvent.totalStaked())
	assertEqual(t, CadenceUFix64(expectedStart.totalSupply), emittedEvent.totalSupply())
	assertEqual(t, CadenceUFix64(expectedStart.rewards), emittedEvent.rewards())

}

// Verifies that the epoch setup event values are equal to the provided expected values
func verifyEpochSetup(
	t *testing.T,
	b emulator.Emulator,
	adapter *adapters.SDKAdapter,
	epochAddress flow.Address,
	expectedSetup EpochSetup) {

	var emittedEvent EpochSetupEvent

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := adapter.GetEventsForHeightRange(context.Background(), "A."+epochAddress.String()+".FlowEpoch.EpochSetup", i, i)

		for _, result := range results {
			for _, event := range result.Events {
				if event.Type == "A."+epochAddress.String()+".FlowEpoch.EpochSetup" {
					emittedEvent = EpochSetupEvent(event)
				}
			}
		}

		i = i + 1
	}

	assertEqual(t, cadence.NewUInt64(expectedSetup.counter), emittedEvent.Counter())

	// node info
	assertEqual(t, expectedSetup.nodeInfoLength, len(emittedEvent.NodeInfo().Values))

	assertEqual(t, cadence.NewUInt64(expectedSetup.firstView), emittedEvent.firstView())
	assertEqual(t, cadence.NewUInt64(expectedSetup.finalView), emittedEvent.finalView())

	// clusters
	verifyClusters(t, expectedSetup.collectorClusters, emittedEvent.collectorClusters().Values)

	phase1View, phase2View, phase3View := emittedEvent.dkgFinalViews()
	assertEqual(t, cadence.NewUInt64(expectedSetup.dkgPhase1FinalView), phase1View)
	assertEqual(t, cadence.NewUInt64(expectedSetup.dkgPhase2FinalView), phase2View)
	assertEqual(t, cadence.NewUInt64(expectedSetup.dkgPhase3FinalView), phase3View)
	assertEqual(t, cadence.NewUInt64(expectedSetup.targetDuration), emittedEvent.targetDuration())
	assertEqual(t, cadence.NewUInt64(expectedSetup.targetEndTime), emittedEvent.targetEndTime())
}

// Verifies that the EpochCommit event values are equal to the provided expected values
func verifyEpochCommit(
	t *testing.T,
	b emulator.Emulator,
	adapter *adapters.SDKAdapter,
	epochAddress flow.Address,
	expectedCommitted EpochCommit) {
	var emittedEvent EpochCommitEvent

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := adapter.GetEventsForHeightRange(context.Background(), "A."+epochAddress.String()+".FlowEpoch.EpochCommit", i, i)

		for _, result := range results {
			for _, event := range result.Events {
				if event.Type == "A."+epochAddress.String()+".FlowEpoch.EpochCommit" {
					emittedEvent = EpochCommitEvent(event)
				}
			}
		}

		i = i + 1
	}

	assertEqual(t, cadence.NewUInt64(expectedCommitted.counter), emittedEvent.Counter())

	// dkg result
	dkgGroupKey := CDCToString(emittedEvent.dkgGroupPubKey())
	dkgPubKeys := CadenceArrayTo(emittedEvent.dkgPubKeys(), CDCToString)
	dkgIDMapping := CDCToDKGIDMapping(emittedEvent.dkgIDMapping())
	assertEqual(t, expectedCommitted.dkgGroupPubKey, dkgGroupKey)
	assertEqual(t, expectedCommitted.dkgPubKeys, dkgPubKeys)
	assertEqual(t, expectedCommitted.dkgIDMapping, dkgIDMapping)

	// quorum certificates
	verifyClusterQCs(t, expectedCommitted.clusterQCs, emittedEvent.clusterQCs().Values)

}

// verifyCollectorClusters verifies both collector clusters are equal.
func verifyCollectorClusters(t *testing.T, expected, got []cadence.Value) {
	for i, cluster := range got {
		for j, node := range cluster.(cadence.Array).Values {
			assertEqual(t, expected[i].(cadence.Array).Values[j], node)
		}
	}
}

// expectedTargetEndTime returns the expected `targetEndTime` for the given target epoch,
// as a second-precision Unix time.
func expectedTargetEndTime(timingConfig cadence.Value, targetEpoch uint64) uint64 {
	fields := cadence.FieldsMappedByName(timingConfig.(cadence.Struct))
	duration := uint64(fields["duration"].(cadence.UInt64))
	refCounter := uint64(fields["refCounter"].(cadence.UInt64))
	refTimestamp := uint64(fields["refTimestamp"].(cadence.UInt64))

	return refTimestamp + duration*(targetEpoch-refCounter)
}

// verifyEpochRecover verifies that an emitted EpochRecover event is equal to the provided `expectedRecover`.
// CAUTION: Assumes that only one such event was emitted, and that it was emitted in the first 1000 blocks.
func verifyEpochRecover(
	t *testing.T,
	adapter *adapters.SDKAdapter,
	epochAddress flow.Address,
	expectedRecover EpochRecover,
) {
	var emittedEvent EpochRecoverEvent
	addrLocation := common.NewAddressLocation(nil, common.Address(epochAddress), "FlowEpoch")
	evtTypeID := string(addrLocation.TypeID(nil, "FlowEpoch.EpochRecover"))
	for i := uint64(0); i < 1000; i++ {
		results, _ := adapter.GetEventsForHeightRange(context.Background(), evtTypeID, i, i)

		for _, result := range results {
			for _, event := range result.Events {

				if event.Type == evtTypeID {
					emittedEvent = EpochRecoverEvent(event)
				}
			}
		}
	}

	assertEqual(t, cadence.NewUInt64(expectedRecover.counter), emittedEvent.Counter())
	assertEqual(t, expectedRecover.nodeInfoLength, len(emittedEvent.NodeInfo().Values))
	assertEqual(t, cadence.NewUInt64(expectedRecover.firstView), emittedEvent.FirstView())
	assertEqual(t, cadence.NewUInt64(expectedRecover.finalView), emittedEvent.FinalView())
	verifyCollectorClusters(t, expectedRecover.collectorClusters, emittedEvent.CollectorClusters().Values)
	assertEqual(t, cadence.String(expectedRecover.randomSource), emittedEvent.RandomSource())
	dkgPhase1FinalView, dkgPhase2FinalView, dkgPhase3FinalView := emittedEvent.DKGFinalViews()
	assertEqual(t, cadence.NewUInt64(expectedRecover.dkgPhase1FinalView), dkgPhase1FinalView)
	assertEqual(t, cadence.NewUInt64(expectedRecover.dkgPhase2FinalView), dkgPhase2FinalView)
	assertEqual(t, cadence.NewUInt64(expectedRecover.dkgPhase3FinalView), dkgPhase3FinalView)
	assertEqual(t, cadence.NewUInt64(expectedRecover.targetDuration), emittedEvent.TargetDuration())
	assertEqual(t, cadence.NewUInt64(expectedRecover.targetEndTime), emittedEvent.TargetEndTime())
	assertEqual(t, expectedRecover.numberClusterQCs, len(emittedEvent.ClusterQCVoteData().Values))
	assertEqual(t, len(expectedRecover.dkgPubKeys), len(emittedEvent.DKGPubKeys().Values))
	assertEqual(t, len(expectedRecover.dkgIdMapping.Pairs), len(emittedEvent.DKGPubKeys().Values))
}

// getEpochMetadata executes a script against the emulator and returns the
// EpochMetadata stored in the FlowEpoch contract for the given epoch counter.
func getEpochMetadata(t *testing.T, b emulator.Emulator, env templates.Environment, counter cadence.Value) map[string]cadence.Value {
	result := executeScriptAndCheck(t, b, templates.GenerateGetEpochMetadataScript(env), [][]byte{jsoncdc.MustEncode(counter)})
	return cadence.FieldsMappedByName(result.(cadence.Struct))
}

// getCurrentEpochCounter executes a script against the emulator and returns the
// current epoch counter field of the FlowEpoch contract.
func getCurrentEpochCounter(t *testing.T, b emulator.Emulator, env templates.Environment) cadence.UInt64 {
	result := executeScriptAndCheck(t, b, templates.GenerateGetCurrentEpochCounterScript(env), [][]byte{})
	return result.(cadence.UInt64)
}

// newClusterQCVoteDataCdcType returns a new (empty) FlowClusterQC cadence struct type.
func newClusterQCVoteDataCdcType(clusterQcAddress string) *cadence.StructType {
	// FlowClusterQC.ClusterQCVoteData
	address, _ := common.HexToAddress(clusterQcAddress)
	location := common.NewAddressLocation(nil, address, "FlowClusterQC")

	return cadence.NewStructType(location, "FlowClusterQC.ClusterQCVoteData",
		[]cadence.Field{
			{
				Identifier: "aggregatedSignature",
				Type:       cadence.StringType,
			},
			{
				Identifier: "voterIDs",
				Type:       cadence.NewVariableSizedArrayType(cadence.StringType),
			},
		},
		nil)
}

// convertClusterQcsCdc expects a list of collection clusters where each entry in the list is a
// list of collector cluster voter ids. This func will create a full collection cluster fixture
// for each of the clusters in the list, creating a aggregate signature fixture for each of the
// clusters.
// Args:
//
//	env: templates environment
//	clusters: list of collection clusters, each cluster being a list of voter ids i.e: cadence.NewArray([]cadence.Value{CadenceString("node_1"), CadenceString("node_2"), CadenceString("node_3")})
//
// Returns:
//
//	[]cadence.Value: array of cluster qc vote data fixtures for each collection cluster.
func convertClusterQcsCdc(env templates.Environment, clusters []cadence.Value) []cadence.Value {
	voteDataType := newClusterQCVoteDataCdcType(env.QuorumCertificateAddress)
	qcVoteData := make([]cadence.Value, len(clusters))
	for i, cluster := range clusters {
		clusterCdc := cluster.(cadence.Array)
		cdcVoterIds := make([]cadence.Value, len(clusterCdc.Values))
		for i, id := range clusterCdc.Values {
			cdcVoterIds[i] = cadence.String(id.String())
		}
		qcVoteData[i] = cadence.NewStruct([]cadence.Value{
			// aggregatedSignature
			cadence.String(fmt.Sprintf("signature_%d", i)),
			// Node IDs of signers
			cadence.NewArray(cdcVoterIds).WithType(cadence.NewVariableSizedArrayType(cadence.StringType)),
		}).WithType(voteDataType)
	}

	return qcVoteData
}

type testEpochConfig struct {
	startEpochCounter    uint64 // start epoch counter
	numEpochViews        uint64 // num views per epoch
	numStakingViews      uint64 // num views for staking auction
	numDKGViews          uint64 // num views for DKG phase
	numClusters          uint64 // num collector clusters
	numEpochAccounts     int    // num accounts to setup for staking
	randomSource         string // random source
	rewardIncreaseFactor string // reward increase factor
}

// runWithDefaultContracts sets up a test environment using the input config, deploys all default contracts,
// then executes the test case defined by input functor f.
func runWithDefaultContracts(t *testing.T, config *testEpochConfig, f func(b emulator.Emulator, env templates.Environment, ids []string, idTableAddress flow.Address, IDTableSigner sdkcrypto.Signer, adapter *adapters.SDKAdapter)) {
	b, adapter, accountKeys, env := newTestSetup(t)
	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// Deploys the staking contract, qc, dkg, and epoch lifecycle contract
	// staking contract is deployed with default values (1.25M rewards, 8% cut)
	idTableAddress, _ := initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		config.startEpochCounter, // start epoch counter
		config.numEpochViews,     // num views per epoch
		config.numStakingViews,   // num views for staking auction
		config.numDKGViews,       // num views for DKG phase
		config.numClusters,       // num collector clusters
		config.randomSource,      // random source
		config.rewardIncreaseFactor)

	// create new user accounts, mint tokens for them, and register them for staking
	addresses, _, signers := registerAndMintManyAccounts(t, b, env, accountKeys, config.numEpochAccounts)
	ids, _, _ := generateNodeIDs(config.numEpochAccounts)
	// stakingPrivateKeys
	stakingPrivateKeys, stakingPublicKeys, _, networkingPublicKeys := generateManyNodeKeys(t, config.numEpochAccounts)
	stakingKeyPOPs := generateManyKeyPOPs(t, stakingPrivateKeys)
	registerNodesForStaking(t, b, env,
		addresses,
		signers,
		stakingPublicKeys,
		stakingKeyPOPs,
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

	f(b, env, ids, idTableAddress, IDTableSigner, adapter)
}

// DKGPubKeyFixture constructs a fixture for a DKG public key string as accepted by FlowDKG
// (any hex-encoded 96-byte bytes).
func DKGPubKeyFixture() string {
	key := make([]byte, 96)
	_, err := rand.Read(key)
	if err != nil {
		panic(err)
	}
	return hex.EncodeToString(key)
}

// DKGPubKeysFixture constructs a fixture for a DKG public key string list as accepted by FlowDKG
// (any list of hex-encoded 96-byte bytes).
func DKGPubKeysFixture(n int) []string {
	keys := make([]string, n)
	for i := range keys {
		keys[i] = DKGPubKeyFixture()
	}
	return keys
}

// DKGPubKeyFixtureCDC returns a Cadence string-typed version of DKGPubKeyFixture.
func DKGPubKeyFixtureCDC() cadence.String {
	return cadence.String(DKGPubKeyFixture())
}

// DKGPubKeysFixtureCDC returns a Cadence array-typed version of DKGPubKeysFixture.
func DKGPubKeysFixtureCDC(n int) cadence.Array {
	values := make([]cadence.Value, n)
	for i := range values {
		values[i] = DKGPubKeyFixtureCDC()
	}
	return cadence.NewArray(values)
}

// DKGIDMappingToCDC converts an ID mapping (map from node IDs to DKG indexes) from a Go
// map representation to a Cadence dictionary representation.
func DKGIDMappingToCDC(idMapping map[string]int) cadence.Dictionary {
	pairs := make([]cadence.KeyValuePair, 0, len(idMapping))
	for nodeID, index := range idMapping {
		pairs = append(pairs, cadence.KeyValuePair{
			Key:   cadence.String(nodeID),
			Value: cadence.NewInt(index),
		})
	}
	return cadence.NewDictionary(pairs)
}

// CDCToDKGIDMapping converts an ID mapping (map from node IDs to DKG indexes) from a
// Cadence dictionary representation to a Go map representation.
func CDCToDKGIDMapping(cdc cadence.Value) map[string]int {
	idMappingCDC := cdc.(cadence.Dictionary)
	idMapping := make(map[string]int, len(idMappingCDC.Pairs))
	for _, pair := range idMappingCDC.Pairs {
		nodeID := string(pair.Key.(cadence.String))
		index := pair.Value.(cadence.Int).Int()
		idMapping[nodeID] = index
	}
	return idMapping
}

// ResultSubmission is a Go structure representation the FlowDKG.ResultSubmission Cadence data structure.
// It is used to construct and operate on ResultSubmission objects from Cadence, in Go tests.
type ResultSubmission struct {
	GroupPubKey string
	PubKeys     []string
	IDMapping   map[string]int
}

// GroupPubKeyCDC returns the GroupPubKey field as a cadence String.
func (rs *ResultSubmission) GroupPubKeyCDC() cadence.String {
	cdc, err := cadence.NewString(rs.GroupPubKey)
	if err != nil {
		panic(err)
	}
	return cdc
}

// PubKeysCDC returns the PubKeys field as a cadence [String].
func (rs *ResultSubmission) PubKeysCDC() cadence.Array {
	values := make([]cadence.Value, len(rs.PubKeys))
	for i := range values {
		var err error
		values[i], err = cadence.NewString(rs.PubKeys[i])
		if err != nil {
			panic(err)
		}
	}
	return cadence.NewArray(values)
}

// IDMappingCDC returns the IDMapping field as a cadence {String: Int}.
func (rs *ResultSubmission) IDMappingCDC() cadence.Dictionary {
	return DKGIDMappingToCDC(rs.IDMapping)
}

// ResultSubmissionFromCadence converts a Cadence-typed ResultSubmission to the Go representation.
func ResultSubmissionFromCadence(cdc cadence.Value) ResultSubmission {
	fields := cdc.(cadence.Struct).FieldsMappedByName()
	rs := ResultSubmission{
		GroupPubKey: string(UnwrapOptional[cadence.String](fields["groupPubKey"])),
		PubKeys:     CadenceArrayTo(UnwrapOptional[cadence.Array](fields["pubKeys"]), CDCToString),
		IDMapping:   CDCToDKGIDMapping(UnwrapOptional[cadence.Dictionary](fields["idMapping"])),
	}
	return rs
}

// GetDKGFinalSubmissions executes a script to retrieve all unique final submissions.
func GetDKGFinalSubmissions(t *testing.T, b emulator.Emulator, env templates.Environment) []ResultSubmission {
	result := executeScriptAndCheck(t, b, templates.GenerateGetDKGFinalSubmissionsScript(env), nil)

	var submissions []ResultSubmission
	for _, submissionCDC := range result.(cadence.Array).Values {
		submissions = append(submissions, ResultSubmissionFromCadence(submissionCDC))
	}
	return submissions
}

// GetDKGCanonicalFinalSubmission executes a script to retrieve the canonical final submission, if any exists.
func GetDKGCanonicalFinalSubmission(t *testing.T, b emulator.Emulator, env templates.Environment) ResultSubmission {
	result := executeScriptAndCheck(t, b, templates.GenerateGetDKGCanonicalFinalSubmissionScript(env), nil)
	return ResultSubmissionFromCadence(UnwrapOptional[cadence.Struct](result))
}
