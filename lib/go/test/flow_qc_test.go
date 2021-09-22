package test

import (
	"encoding/hex"
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

	flow_crypto "github.com/onflow/flow-go/crypto"
	"github.com/onflow/flow-go/model/encoding"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

// This function initializes Cluster records in order to pass the cluster information
// as an argument to the startVoting transaction
// It assigns nodes to a whole cluster first,
// then the next cluster, and so on
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

			nodeIDs[j] = CadenceString(nodeID)

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
			Name:   "FlowClusterQC",
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
	joshPrivateStakingKey, joshPublicStakingKey, _, _ := generateKeysForNodeRegistration(t)

	// Create a new user account
	maxAccountKey, maxSigner := accountKeys.NewWithSigner()
	maxAddress, _ := b.CreateAccount([]*flow.AccountKey{maxAccountKey}, nil)
	maxPrivateStakingKey, maxPublicStakingKey, _, _ := generateKeysForNodeRegistration(t)

	collectorVoteHasher := flow_crypto.NewBLSKMAC(encoding.CollectorVoteTag)

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
		_ = tx.AddArgument(CadenceString(maxID))
		_ = tx.AddArgument(CadenceString(maxPublicStakingKey))

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

	startVotingArguments := initClusters(clusterNodeIDStrings, numberOfClusters, numberOfNodesPerCluster)

	t.Run("Should start voting with the admin", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartVotingScript(env), QCAddress)

		err := tx.AddArgument(cadence.NewArray(startVotingArguments[0]))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(startVotingArguments[1]))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(startVotingArguments[2]))
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
		_ = tx.AddArgument(CadenceString(clusterNodeIDStrings[0][0]))
		_ = tx.AddArgument(CadenceString(maxPublicStakingKey))

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
		_ = tx.AddArgument(CadenceString(clusterNodeIDStrings[0][0]))
		_ = tx.AddArgument(CadenceString(joshPublicStakingKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)
	})

	t.Run("Should not be able to submit an empty vote signature", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), QCAddress)

		_ = tx.AddArgument(CadenceString(""))
		_ = tx.AddArgument(CadenceString("not empty"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			true,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})

		assert.Equal(t, cadence.NewBool(false), result)
	})

	t.Run("Should not be able to submit an empty vote message", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), QCAddress)

		_ = tx.AddArgument(CadenceString("not empty"))
		_ = tx.AddArgument(CadenceString(""))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			true,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})

		assert.Equal(t, cadence.NewBool(false), result)
	})

	t.Run("Should not be able to submit a vote that is an invalid signature", func(t *testing.T) {

		// construct an invalid signature, signed by the wrong key (josh key)
		msg, _ := hex.DecodeString("deadbeef")
		invalidSignature, err := joshPrivateStakingKey.Sign(msg, collectorVoteHasher)
		invalidSignatureString := invalidSignature.String()[2:]
		assert.NoError(t, err)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), QCAddress)

		_ = tx.AddArgument(CadenceString(invalidSignatureString))
		_ = tx.AddArgument(CadenceString("deadbeef"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			true,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})

		assert.Equal(t, cadence.NewBool(false), result)

		// construct with the wrong tag
		wrongHasher := flow_crypto.NewBLSKMAC(encoding.ConsensusVoteTag)

		msg, _ = hex.DecodeString("deadbeef")
		invalidSignature, err = maxPrivateStakingKey.Sign(msg, wrongHasher)
		invalidSignatureString = invalidSignature.String()[2:]
		assert.NoError(t, err)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), QCAddress)

		_ = tx.AddArgument(CadenceString(invalidSignatureString))
		_ = tx.AddArgument(CadenceString("deadbeef"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			true,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})

		assert.Equal(t, cadence.NewBool(false), result)

		// construct with a mismatch of the message
		msg, _ = hex.DecodeString("beefdead")
		invalidSignature, err = joshPrivateStakingKey.Sign(msg, collectorVoteHasher)
		invalidSignatureString = invalidSignature.String()[2:]
		assert.NoError(t, err)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), QCAddress)

		_ = tx.AddArgument(CadenceString(invalidSignatureString))
		_ = tx.AddArgument(CadenceString("deadbeef"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			true,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetNodeHasVotedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(clusterNodeIDStrings[0][0]))})

		assert.Equal(t, cadence.NewBool(false), result)
	})

	t.Run("Should be able to submit a valid vote", func(t *testing.T) {

		// Construct a valid message and signature with max Key
		msg, _ := hex.DecodeString("deadbeef")
		validSignature, err := maxPrivateStakingKey.Sign(msg, collectorVoteHasher)
		validSignatureString := validSignature.String()[2:]
		assert.NoError(t, err)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), QCAddress)

		_ = tx.AddArgument(CadenceString(validSignatureString))
		_ = tx.AddArgument(CadenceString("deadbeef"))

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

		result = executeScriptAndCheck(t, b, templates.GenerateGetVotingCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetClusterCompleteScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0)))})
		assert.Equal(t, cadence.NewBool(true), result)
	})

	t.Run("Should not be able to submit a vote a second time", func(t *testing.T) {

		// Construct a valid signature with max key but will fail because it has already been submitted
		validSignature, err := maxPrivateStakingKey.Sign([]byte("deadbeef"), collectorVoteHasher)
		validSignatureString := validSignature.String()[2:]
		assert.NoError(t, err)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), QCAddress)

		_ = tx.AddArgument(CadenceString(validSignatureString))
		_ = tx.AddArgument(CadenceString("deadbeef"))

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

	numberOfClusters = 2
	numberOfNodesPerCluster = 3

	clusterNodeIDStrings = make([][]string, numberOfClusters*numberOfNodesPerCluster)

	startVotingArguments = initClusters(clusterNodeIDStrings, numberOfClusters, numberOfNodesPerCluster)

	t.Run("Should start voting with the admin with more nodes and clusters", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartVotingScript(env), QCAddress)

		err := tx.AddArgument(cadence.NewArray(startVotingArguments[0]))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(startVotingArguments[1]))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(startVotingArguments[2]))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)

	})

	t.Run("Should not be able to claim a voter resource for a node who has already claimed it", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateVoterScript(env), joshAddress)

		_ = tx.AddArgument(cadence.NewAddress(QCAddress))
		_ = tx.AddArgument(CadenceString(clusterNodeIDStrings[0][0]))
		_ = tx.AddArgument(CadenceString(joshPublicStakingKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

	})
}

func TestQuorumCertificateMoreNodes(t *testing.T) {
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
			Name:   "FlowClusterQC",
			Source: string(QCCode),
		},
	})
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}

	env.QuorumCertificateAddress = QCAddress.Hex()

	collectorVoteHasher := flow_crypto.NewBLSKMAC(encoding.CollectorVoteTag)

	t.Run("Should be able to set up the admin account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GeneratePublishVoterScript(env), QCAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)
	})

	numberOfClusters := 3
	numberOfNodesPerCluster := 4

	// Create new user accounts
	addresses, _, signers := registerAndMintManyAccounts(t, b, accountKeys, numberOfClusters*numberOfNodesPerCluster)

	clusterNodeIDStrings := make([][]string, numberOfClusters*numberOfNodesPerCluster)

	stakingPrivateKeys, stakingPublicKeys, _, _ := generateManyNodeKeys(t, numberOfClusters*numberOfNodesPerCluster)

	// initializes clusters by filling them all in in order
	// Other tests continue this cluster organization assumption
	startVotingArguments := initClusters(clusterNodeIDStrings, numberOfClusters, numberOfNodesPerCluster)

	t.Run("Should start voting with the admin with more nodes and clusters", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartVotingScript(env), QCAddress)

		err := tx.AddArgument(cadence.NewArray(startVotingArguments[0]))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(startVotingArguments[1]))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(startVotingArguments[2]))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, QCAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
			false,
		)

	})

	t.Run("Should claim voter resources for new accounts", func(t *testing.T) {

		for i := 0; i < numberOfClusters*numberOfNodesPerCluster; i++ {

			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateVoterScript(env), addresses[i])

			_ = tx.AddArgument(cadence.NewAddress(QCAddress))
			_ = tx.AddArgument(CadenceString(clusterNodeIDStrings[i/numberOfNodesPerCluster][i%numberOfNodesPerCluster]))
			_ = tx.AddArgument(CadenceString(stakingPublicKeys[i]))

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address, addresses[i]},
				[]crypto.Signer{b.ServiceKey().Signer(), signers[i]},
				false,
			)
		}

	})

	t.Run("Should register incomplete if only one of the clusters is complete", func(t *testing.T) {

		for i := 0; i < numberOfNodesPerCluster; i++ {

			// Construct a valid message and signature
			msg, _ := hex.DecodeString("deadbeef")
			validSignature, err := stakingPrivateKeys[i].Sign(msg, collectorVoteHasher)
			validSignatureString := validSignature.String()[2:]
			assert.NoError(t, err)

			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), addresses[i])

			_ = tx.AddArgument(CadenceString(validSignatureString))
			_ = tx.AddArgument(CadenceString("deadbeef"))

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address, addresses[i]},
				[]crypto.Signer{b.ServiceKey().Signer(), signers[i]},
				false,
			)
		}

		result := executeScriptAndCheck(t, b, templates.GenerateGetVotingCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetClusterCompleteScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0)))})
		assert.Equal(t, cadence.NewBool(true), result)

	})

	// If a cluster has received votes with weight exceeding the quorum threshold, but those
	// votes are spread across different vote messages such that no set of votes corresponding
	// to any vote message represents weight exceeding the quorum threshold, the cluster voting
	// should be considered incomplete.
	t.Run("Should register incomplete if a cluster has different vote messages", func(t *testing.T) {

		for i := numberOfNodesPerCluster; i < numberOfNodesPerCluster*2-2; i++ {

			// Construct a valid message and signature
			msg, _ := hex.DecodeString("beefdead")
			validSignature, err := stakingPrivateKeys[i].Sign(msg, collectorVoteHasher)
			validSignatureString := validSignature.String()[2:]
			assert.NoError(t, err)

			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), addresses[i])

			_ = tx.AddArgument(CadenceString(validSignatureString))
			_ = tx.AddArgument(CadenceString("beefdead"))

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address, addresses[i]},
				[]crypto.Signer{b.ServiceKey().Signer(), signers[i]},
				false,
			)

			result := executeScriptAndCheck(t, b, templates.GenerateGetVotingCompletedScript(env), nil)
			assert.Equal(t, cadence.NewBool(false), result)

			result = executeScriptAndCheck(t, b, templates.GenerateGetClusterCompleteScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(1)))})
			assert.Equal(t, cadence.NewBool(false), result)
		}

		// Construct a valid message and signature
		msg, _ := hex.DecodeString("deebaf")

		// Sign with the third node from the second cluster
		validSignature, err := stakingPrivateKeys[numberOfNodesPerCluster*2-2].Sign(msg, collectorVoteHasher)
		validSignatureString := validSignature.String()[2:]
		assert.NoError(t, err)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), addresses[numberOfNodesPerCluster*2-2])

		_ = tx.AddArgument(CadenceString(validSignatureString))
		_ = tx.AddArgument(CadenceString("deebaf"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, addresses[numberOfNodesPerCluster*2-2]},
			[]crypto.Signer{b.ServiceKey().Signer(), signers[numberOfNodesPerCluster*2-2]},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetVotingCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)
		result = executeScriptAndCheck(t, b, templates.GenerateGetClusterCompleteScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(1)))})
		assert.Equal(t, cadence.NewBool(false), result)

		// Sign with the fourth node from the second cluster
		validSignature, err = stakingPrivateKeys[numberOfNodesPerCluster*2-1].Sign(msg, collectorVoteHasher)
		validSignatureString = validSignature.String()[2:]
		assert.NoError(t, err)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), addresses[numberOfNodesPerCluster*2-1])

		_ = tx.AddArgument(CadenceString(validSignatureString))
		_ = tx.AddArgument(CadenceString("deebaf"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, addresses[numberOfNodesPerCluster*2-1]},
			[]crypto.Signer{b.ServiceKey().Signer(), signers[numberOfNodesPerCluster*2-1]},
			false,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetVotingCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)
		result = executeScriptAndCheck(t, b, templates.GenerateGetClusterCompleteScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(1)))})
		assert.Equal(t, cadence.NewBool(false), result)

	})

	// If a cluster has received identical votes with weight exceeding the quorum threshold,
	// and there is a different vote that doesn't match the quroum votes,
	// the cluster voting should still be considered complete
	t.Run("Should register that the cluster is complete even if it has a vote different than the quorum", func(t *testing.T) {

		for i := numberOfNodesPerCluster * 2; i < numberOfNodesPerCluster*3-1; i++ {

			// Construct a valid message and signature
			msg, _ := hex.DecodeString("beefdead")
			validSignature, err := stakingPrivateKeys[i].Sign(msg, collectorVoteHasher)
			validSignatureString := validSignature.String()[2:]
			assert.NoError(t, err)

			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), addresses[i])

			_ = tx.AddArgument(CadenceString(validSignatureString))
			_ = tx.AddArgument(CadenceString("beefdead"))

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address, addresses[i]},
				[]crypto.Signer{b.ServiceKey().Signer(), signers[i]},
				false,
			)
		}

		result := executeScriptAndCheck(t, b, templates.GenerateGetVotingCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetClusterCompleteScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(2)))})
		assert.Equal(t, cadence.NewBool(true), result)

		// Construct a valid message and signature
		msg, _ := hex.DecodeString("deebaf")

		// Sign with the last node from the third cluster
		validSignature, err := stakingPrivateKeys[numberOfNodesPerCluster*3-1].Sign(msg, collectorVoteHasher)
		validSignatureString := validSignature.String()[2:]
		assert.NoError(t, err)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), addresses[numberOfNodesPerCluster*3-1])

		_ = tx.AddArgument(CadenceString(validSignatureString))
		_ = tx.AddArgument(CadenceString("deebaf"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, addresses[numberOfNodesPerCluster*3-1]},
			[]crypto.Signer{b.ServiceKey().Signer(), signers[numberOfNodesPerCluster*3-1]},
			false,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetVotingCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)
		result = executeScriptAndCheck(t, b, templates.GenerateGetClusterCompleteScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(2)))})
		assert.Equal(t, cadence.NewBool(true), result)
	})
}

func TestQuorumCertificateNotSubmittedVote(t *testing.T) {
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
			Name:   "FlowClusterQC",
			Source: string(QCCode),
		},
	})
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}

	env.QuorumCertificateAddress = QCAddress.Hex()

	collectorVoteHasher := flow_crypto.NewBLSKMAC(encoding.CollectorVoteTag)

	tx := createTxWithTemplateAndAuthorizer(b, templates.GeneratePublishVoterScript(env), QCAddress)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, QCAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
		false,
	)

	numberOfClusters := 1
	numberOfNodesPerCluster := 4

	// Create new user accounts
	addresses, _, signers := registerAndMintManyAccounts(t, b, accountKeys, numberOfClusters*numberOfNodesPerCluster)

	clusterNodeIDStrings := make([][]string, numberOfClusters*numberOfNodesPerCluster)

	stakingPrivateKeys, stakingPublicKeys, _, _ := generateManyNodeKeys(t, numberOfClusters*numberOfNodesPerCluster)

	// initializes clusters by filling them all in in order
	// Other tests continue this cluster organization assumption
	startVotingArguments := initClusters(clusterNodeIDStrings, numberOfClusters, numberOfNodesPerCluster)

	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateStartVotingScript(env), QCAddress)

	err = tx.AddArgument(cadence.NewArray(startVotingArguments[0]))
	require.NoError(t, err)

	err = tx.AddArgument(cadence.NewArray(startVotingArguments[1]))
	require.NoError(t, err)

	err = tx.AddArgument(cadence.NewArray(startVotingArguments[2]))
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, QCAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), QCSigner},
		false,
	)

	// Claim voter resources
	for i := 0; i < numberOfClusters*numberOfNodesPerCluster; i++ {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateVoterScript(env), addresses[i])

		_ = tx.AddArgument(cadence.NewAddress(QCAddress))
		_ = tx.AddArgument(CadenceString(clusterNodeIDStrings[i/numberOfNodesPerCluster][i%numberOfNodesPerCluster]))
		_ = tx.AddArgument(CadenceString(stakingPublicKeys[i]))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, addresses[i]},
			[]crypto.Signer{b.ServiceKey().Signer(), signers[i]},
			false,
		)
	}

	t.Run("Should generate a valid quorum certificate even if a node hasn't voted", func(t *testing.T) {

		for i := 0; i < numberOfNodesPerCluster-1; i++ {

			// Construct a valid message and signature
			msg, _ := hex.DecodeString("deadbeef")
			validSignature, err := stakingPrivateKeys[i].Sign(msg, collectorVoteHasher)
			validSignatureString := validSignature.String()[2:]
			assert.NoError(t, err)

			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSubmitVoteScript(env), addresses[i])

			_ = tx.AddArgument(CadenceString(validSignatureString))
			_ = tx.AddArgument(CadenceString("deadbeef"))

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address, addresses[i]},
				[]crypto.Signer{b.ServiceKey().Signer(), signers[i]},
				false,
			)
		}

		result := executeScriptAndCheck(t, b, templates.GenerateGetVotingCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetClusterCompleteScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0)))})
		assert.Equal(t, cadence.NewBool(true), result)

		executeScriptAndCheck(t, b, templates.GenerateGenerateQuorumCertificateScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt16(uint16(0)))})

	})

}
