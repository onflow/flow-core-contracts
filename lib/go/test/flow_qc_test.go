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

// This function initializes Cluster records in order to pass the cluster information
// as an argument to the startVoting transaction
func initClusters(clusterNodeIDStrings [][]string, numberOfClusters, numberOfNodesPerCluster int) [][]cadence.Value {
	clusterIndices := make([]cadence.Value, numberOfClusters)
	clusterNodeIDs := make([]cadence.Value, numberOfClusters)
	clusterNodeWeights := make([]cadence.Value, numberOfClusters)

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

	return [][]cadence.Value{clusterIndices, clusterNodeIDs, clusterNodeWeights}
}

func TestQuorumCertificate(t *testing.T) {
	b := newBlockchain()

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

	// Create a new user account
	maxAccountKey, maxSigner := accountKeys.NewWithSigner()
	maxAddress, _ := b.CreateAccount([]*flow.AccountKey{maxAccountKey}, nil)

	// // Create a new user account
	// bastianAccountKey, bastianSigner := accountKeys.NewWithSigner()
	// bastianAddress, _ := b.CreateAccount([]*flow.AccountKey{bastianAccountKey}, nil)

	// // Create a new user account for access node
	// accessAccountKey, accessSigner := accountKeys.NewWithSigner()
	// accessAddress, _ := b.CreateAccount([]*flow.AccountKey{accessAccountKey}, nil)

	t.Run("Should be able to set up the admin account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GeneratePublishVoterScript(env), QCAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)
	})

	t.Run("Should be able to register a voter even if the node hasn't been registered in a cluster", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateVoterScript(env), maxAddress)

		_ = tx.AddArgument(cadence.NewAddress(QCAddress))
		_ = tx.AddArgument(cadence.NewString(maxID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)
	})

	////////////////////////// FIRST EPOCH ///////////////////////////////////

	numberOfClusters := 1
	numberOfNodesPerCluster := 1

	clusterNodeIDStrings := make([][]string, numberOfClusters)

	clusters := initClusters(clusterNodeIDStrings, numberOfClusters, numberOfNodesPerCluster)

	t.Run("Should start voting with the admin", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartVotingScript(env), QCAddress)

		err := tx.AddArgument(cadence.NewArray(clusters[0]))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(clusters[1]))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(clusters[2]))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetClusterWeightScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0)))})

		assert.Equal(t, cadence.NewUInt64(100), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetNodeWeightScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0))), jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})

		assert.Equal(t, cadence.NewUInt64(100), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetClusterVoteThresholdScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0)))})

		assert.Equal(t, cadence.NewUInt64(67), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetQCEnabledScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetVoterIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})

		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetVoterIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})

		assert.Equal(t, cadence.NewBool(false), result)

	})

	t.Run("Should be able to get a voter object", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateVoterScript(env), QCAddress)

		_ = tx.AddArgument(cadence.NewAddress(QCAddress))
		_ = tx.AddArgument(cadence.NewString(clusterNodeIDStrings[0][0]))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})

		assert.Equal(t, cadence.NewBool(false), result)
	})

	t.Run("Admin should not be able to stop voting until the quorum has been reached", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStopVotingScript(env), QCAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			true,
		)
	})

	t.Run("Should not be able to register a voter if the node has already been registered", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateVoterScript(env), joshAddress)

		_ = tx.AddArgument(cadence.NewAddress(QCAddress))
		_ = tx.AddArgument(cadence.NewString(clusterNodeIDStrings[0][0]))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)
	})

	t.Run("Should not be able to submit an empty vote", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), QCAddress)

		_ = tx.AddArgument(cadence.NewString(""))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			true,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})

		assert.Equal(t, cadence.NewBool(false), result)
	})

	t.Run("Should be able to submit a vote", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), QCAddress)

		_ = tx.AddArgument(cadence.NewString("0000000000000000000000000000000000000000000000000000000000000000"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})

		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetVoterIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})

		assert.Equal(t, cadence.NewBool(true), result)
	})

	t.Run("Should not be able to submit a vote a second time", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), QCAddress)

		_ = tx.AddArgument(cadence.NewString("0000000000000000000000000000000000000000000000000000000000000000"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			true,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})

		assert.Equal(t, cadence.NewBool(true), result)
	})

	t.Run("Admin should be able to stop voting", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStopVotingScript(env), QCAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)
	})

	///////////////////////////// Epoch 2 ////////////////////////////////////

	// mature
	// numberOfClusters = 10
	// numberOfNodesPerCluster = 80

	numberOfClusters = 5
	numberOfNodesPerCluster = 10

	clusterNodeIDStrings = make([][]string, numberOfClusters)

	clusters = initClusters(clusterNodeIDStrings, numberOfClusters, numberOfNodesPerCluster)

	t.Run("Should start voting with the admin with more nodes and clusters", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartVotingScript(env), QCAddress)

		err := tx.AddArgument(cadence.NewArray(clusters[0]))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(clusters[1]))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(clusters[2]))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)

	})
}
