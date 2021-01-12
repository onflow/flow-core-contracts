package test

import (
	"fmt"
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/onflow/flow-go-sdk/test"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

const (
	numberOfClusters        = 1
	numberOfNodesPerCluster = 1
)

func TestQuroumCertificate(t *testing.T) {
	b := newEmulator()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the QC account and deploy
	QCAccountKey, QCSigner := accountKeys.NewWithSigner()
	QCCode := contracts.FlowQC()

	QCAddress, err := b.CreateAccount([]*flow.AccountKey{QCAccountKey}, []sdktemplates.Contract{
		{
			Name:   "FlowEpochClusterQC",
			Source: string(QCCode),
		},
	})
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}

	env.QuorumCertificateAddress = QCAddress.Hex()

	// Create new user accounts
	joshAccountKey, joshSigner := accountKeys.NewWithSigner()
	joshAddress, _ := b.CreateAccount([]*flow.AccountKey{joshAccountKey}, nil)

	// // Create a new user account
	// maxAccountKey, maxSigner := accountKeys.NewWithSigner()
	// maxAddress, _ := b.CreateAccount([]*flow.AccountKey{maxAccountKey}, nil)

	// // Create a new user account
	// bastianAccountKey, bastianSigner := accountKeys.NewWithSigner()
	// bastianAddress, _ := b.CreateAccount([]*flow.AccountKey{bastianAccountKey}, nil)

	// // Create a new user account for access node
	// accessAccountKey, accessSigner := accountKeys.NewWithSigner()
	// accessAddress, _ := b.CreateAccount([]*flow.AccountKey{accessAccountKey}, nil)

	t.Run("Should be able to set up the admin account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GeneratePublishVoterScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(QCAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)
	})

	t.Run("Should not be able to register a voter if the node hasn't been registered in a cluster", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateVoterScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(QCAddress)

		_ = tx.AddArgument(cadence.NewAddress(QCAddress))
		_ = tx.AddArgument(cadence.NewString(adminID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			true,
		)
	})

	clusterIndices := make([]cadence.Value, numberOfClusters)
	clusterNodeIDs := make([]cadence.Value, numberOfClusters)
	clusterNodeWeights := make([]cadence.Value, numberOfClusters)

	clusterNodeIDStrings := make([][]string, numberOfClusters)

	t.Run("Should start voting with the admin", func(t *testing.T) {

		for i := 0; i < numberOfClusters; i++ {

			clusterIndices[i] = cadence.NewUInt16(uint16(i))

			nodeIDs := make([]cadence.Value, numberOfNodesPerCluster)
			nodeWeights := make([]cadence.Value, numberOfNodesPerCluster)

			nodeIDStrings := make([]string, numberOfNodesPerCluster)

			for j := 0; j < numberOfNodesPerCluster; j++ {
				nodeID := fmt.Sprintf("%064d", i*numberOfNodesPerCluster+j)

				nodeIDs[j] = cadence.NewString(nodeID)

				// default weight per node
				nodeWeights[j] = cadence.NewUInt64(uint64(100))

				nodeIDStrings[j] = nodeID
				clusterNodeIDStrings[i] = nodeIDStrings
			}

			clusterNodeIDs[i] = cadence.NewArray(nodeIDs)
			clusterNodeWeights[i] = cadence.NewArray(nodeWeights)

		}

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStartVotingScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(QCAddress)

		err := tx.AddArgument(cadence.NewArray(clusterIndices))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(clusterNodeIDs))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(clusterNodeWeights))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetClusterWeightScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0)))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		weight := result.Value
		assert.Equal(t, weight.(cadence.UInt64), cadence.NewUInt64(100))

		result, err = b.ExecuteScript(templates.GenerateGetNodeWeightScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0))), jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		weight = result.Value
		assert.Equal(t, weight.(cadence.UInt64), cadence.NewUInt64(100))

		result, err = b.ExecuteScript(templates.GenerateGetClusterVoteThresholdScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0)))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		weight = result.Value
		assert.Equal(t, weight.(cadence.UInt64), cadence.NewUInt64(67))

	})

	t.Run("Should be able to register a voter", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateVoterScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(QCAddress)

		_ = tx.AddArgument(cadence.NewAddress(QCAddress))
		_ = tx.AddArgument(cadence.NewString(clusterNodeIDStrings[0][0]))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		hasVoted := result.Value
		assert.Equal(t, hasVoted.(cadence.Bool), cadence.NewBool(false))
	})

	t.Run("Admin should not be able to stop voting until the quorum has been reached", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStopVotingScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(QCAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			true,
		)
	})

	t.Run("Should not be able to register a voter if the node has already been registered", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateVoterScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		_ = tx.AddArgument(cadence.NewAddress(QCAddress))
		_ = tx.AddArgument(cadence.NewString(adminID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)
	})

	t.Run("Should not be able to submit an empty vote", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateSubmitVoteScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(QCAddress)

		_ = tx.AddArgument(cadence.NewString(""))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			true,
		)

		result, err := b.ExecuteScript(templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		hasVoted := result.Value
		assert.Equal(t, hasVoted.(cadence.Bool), cadence.NewBool(false))
	})

	t.Run("Should be able to submit a vote", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateSubmitVoteScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(QCAddress)

		_ = tx.AddArgument(cadence.NewString("0000000000000000000000000000000000000000000000000000000000000000"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		hasVoted := result.Value
		assert.Equal(t, hasVoted.(cadence.Bool), cadence.NewBool(true))
	})

	t.Run("Should not be able to submit a vote a second time", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateSubmitVoteScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(QCAddress)

		_ = tx.AddArgument(cadence.NewString("0000000000000000000000000000000000000000000000000000000000000000"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			true,
		)

		result, err := b.ExecuteScript(templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		hasVoted := result.Value
		assert.Equal(t, hasVoted.(cadence.Bool), cadence.NewBool(true))
	})

	t.Run("Admin should be able to stop voting", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStopVotingScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(QCAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)
	})
}
