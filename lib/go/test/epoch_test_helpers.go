package test

import (
	"fmt"
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	emulator "github.com/onflow/flow-emulator"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/stretchr/testify/assert"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

type EpochMetadata struct {
	counter           uint64
	seed              string
	startView         uint64
	endView           uint64
	stakingEndView    uint64
	collectorClusters []uint16
	clusterQCs        [][]string
	dkgKeys           []string
}

type EpochSetup struct {
	counter            uint64
	firstView          uint64
	finalView          uint64
	randomSource       string
	dkgPhase1FinalView uint64
	dkgPhase2FinalView uint64
	dkgPhase3FinalView uint64
}

type EpochCommitted struct {
	counter    uint64
	dkgPubKeys []string
	clusterQCs [][]string
}

func deployQCDKGContract(t *testing.T, b *emulator.Blockchain, idTableAddress flow.Address, IDTableSigner crypto.Signer, env templates.Environment) {

	QCCode := contracts.FlowQC()
	QCByteCode := bytesToCadenceArray(QCCode)

	DKGCode := contracts.FlowDKG()
	DKGByteCode := bytesToCadenceArray(DKGCode)

	// Deploy the QC and DKG contracts
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDeployQCDKGScript(env), idTableAddress).
		AddRawArgument(jsoncdc.MustEncode(cadence.NewString("FlowEpochClusterQC"))).
		AddRawArgument(jsoncdc.MustEncode(QCByteCode)).
		AddRawArgument(jsoncdc.MustEncode(cadence.NewString("FlowDKG"))).
		AddRawArgument(jsoncdc.MustEncode(DKGByteCode))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, idTableAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
		false,
	)
}

func deployEpochContract(
	t *testing.T,
	b *emulator.Blockchain,
	idTableAddress flow.Address,
	IDTableSigner crypto.Signer,
	env templates.Environment,
	epochCounter, epochViews, stakingViews, dkgViews, numClusters uint64,
	randomSource string) {

	EpochCode := contracts.FlowEpoch(emulatorFTAddress, emulatorFlowTokenAddress, idTableAddress.String(), idTableAddress.String(), idTableAddress.String())
	EpochByteCode := bytesToCadenceArray(EpochCode)

	// Deploy the Epoch contract
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDeployEpochScript(env), idTableAddress).
		AddRawArgument(jsoncdc.MustEncode(cadence.NewString("FlowEpoch"))).
		AddRawArgument(jsoncdc.MustEncode(EpochByteCode))

	_ = tx.AddArgument(cadence.NewUInt64(epochCounter))
	_ = tx.AddArgument(cadence.NewUInt64(epochViews))
	_ = tx.AddArgument(cadence.NewUInt64(stakingViews))
	_ = tx.AddArgument(cadence.NewUInt64(dkgViews))
	_ = tx.AddArgument(cadence.NewUInt16(uint16(numClusters)))
	_ = tx.AddArgument(cadence.NewString(randomSource))
	_ = tx.AddArgument(cadence.NewArray([]cadence.Value{}))
	_ = tx.AddArgument(cadence.NewArray([]cadence.Value{}))
	_ = tx.AddArgument(cadence.NewArray([]cadence.Value{}))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, idTableAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
		false,
	)
}

func initializeAllEpochContracts(
	t *testing.T,
	b *emulator.Blockchain,
	IDTableAccountKey *flow.AccountKey,
	IDTableSigner crypto.Signer,
	env *templates.Environment,
	epochCounter, epochViews, stakingViews, dkgViews, numClusters uint64,
	randomSource string) flow.Address {

	var idTableAddress = deployStakingContract(t, b, IDTableAccountKey, *env)
	env.IDTableAddress = idTableAddress.Hex()

	deployQCDKGContract(t, b, idTableAddress, IDTableSigner, *env)
	deployEpochContract(t, b, idTableAddress, IDTableSigner, *env, epochCounter, epochViews, stakingViews, dkgViews, numClusters, randomSource)

	env.QuorumCertificateAddress = idTableAddress.String()
	env.DkgAddress = idTableAddress.String()
	env.EpochAddress = idTableAddress.String()
	env.IDTableAddress = idTableAddress.String()

	return idTableAddress
}

func verifyEpochMetadata(
	t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	expectedMetadata EpochMetadata) {

	result := executeScriptAndCheck(t, b, templates.GenerateGetEpochMetadataScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt64(0))})
	metadataFields := result.(cadence.Struct).Fields

	counter := metadataFields[0]
	assertEqual(t, cadence.NewUInt64(expectedMetadata.counter), counter)

	seed := metadataFields[1]
	assertEqual(t, cadence.NewString(expectedMetadata.seed), seed)

	startView := metadataFields[2]
	assertEqual(t, cadence.NewUInt64(expectedMetadata.startView), startView)

	endView := metadataFields[3]
	assertEqual(t, cadence.NewUInt64(expectedMetadata.endView), endView)

	stakingEndView := metadataFields[4]
	assertEqual(t, cadence.NewUInt64(expectedMetadata.stakingEndView), stakingEndView)

	if expectedMetadata.collectorClusters != nil {
		// check collector clusters
	}

	clusterQCs := metadataFields[6].(cadence.Array).Values
	if expectedMetadata.clusterQCs == nil {
		assert.Empty(t, clusterQCs)
	} else {
		for _, qc := range clusterQCs {
			// Verify that each element is correct across the cluster
			fmt.Printf(qc.String())
		}
	}

	dkgKeys := metadataFields[7].(cadence.Array).Values
	if expectedMetadata.dkgKeys == nil {
		assert.Empty(t, dkgKeys)
	} else {
		for _, key := range dkgKeys {
			// Verify that each key is correct
			fmt.Printf(key.String())
		}
	}

}

// func verifyEpochSetup(
// 	t *testing.T,
// 	b *emulator.Blockchain,
// 	epochAddress flow.Address,
// 	setup EpochSetup)
// {

// }

// func verifyEpochCommitted(
// 	t *testing.T,
// 	b *emulator.Blockchain,
// 	epochAddress flow.Address,
// 	committed EpochCommitted)
// {

// }
