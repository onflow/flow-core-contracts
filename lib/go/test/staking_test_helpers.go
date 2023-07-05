package test

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/cadence/runtime/interpreter"
	emulator "github.com/onflow/flow-emulator"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"

	flow_crypto "github.com/onflow/flow-go/crypto"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

// / Used to verify the EpochSetup event fields in tests
type EpochTotalRewardsPaid struct {
	total      string
	fromFees   string
	minted     string
	feesBurned string
}

// Go event definitions for the epoch events
// Can be used with the SDK to retreive and parse epoch events

type EpochTotalRewardsPaidEvent flow.Event

func (evt EpochTotalRewardsPaidEvent) Total() cadence.UFix64 {
	return evt.Value.Fields[0].(cadence.UFix64)
}

func (evt EpochTotalRewardsPaidEvent) FromFees() cadence.UFix64 {
	return evt.Value.Fields[1].(cadence.UFix64)
}

func (evt EpochTotalRewardsPaidEvent) Minted() cadence.UFix64 {
	return evt.Value.Fields[2].(cadence.UFix64)
}

func (evt EpochTotalRewardsPaidEvent) FeesBurned() cadence.UFix64 {
	return evt.Value.Fields[3].(cadence.UFix64)
}

func stubInterpreter() *interpreter.Interpreter {
	inter, _ := interpreter.NewInterpreter(nil, nil, &interpreter.Config{})
	return inter
}

// Defines utility functions that are used for testing the staking contract
// such as deploying the contract, performing staking operations,
// and verifying staking information for nodes and delegators

// Deploys the FlowIDTableStaking contract to a new account with the provided key
//
// parameter: latest: Indicates if the contract should be the latest version.
//
//	This is only set to false when testing staking contract upgrades
func deployStakingContract(
	t *testing.T,
	b *emulator.Blockchain,
	IDTableAccountKey *flow.AccountKey,
	IDTableSigner crypto.Signer,
	env *templates.Environment,
	latest bool,
	candidateNodeLimits []uint64,
) (flow.Address, flow.Address) {

	// create the public key array for the staking and fees account
	publicKeys := make([]cadence.Value, 1)
	publicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(IDTableAccountKey)
	publicKeys[0] = publicKey
	cadencePublicKeys := cadence.NewArray(publicKeys)

	// Get the code byte-array for the fees contract
	FeesCode := contracts.TestFlowFees(emulatorFTAddress, emulatorFlowTokenAddress, emulatorStorageFees)

	// Deploy the fees contract
	feesAddr, err := b.CreateAccount([]*flow.AccountKey{IDTableAccountKey}, []sdktemplates.Contract{
		{
			Name:   "FlowFees",
			Source: string(FeesCode),
		},
	})
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}
	_, err = b.CommitBlock()
	assert.NoError(t, err)

	env.FlowFeesAddress = feesAddr.Hex()

	// Get the code byte-array for the staking contract
	IDTableCode := contracts.FlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress, feesAddr.String(), latest)
	cadenceCode := bytesToCadenceArray(IDTableCode)

	// Create the deployment transaction that transfers a FlowToken minter
	// to the new account and deploys the IDTableStaking contract
	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateTransferMinterAndDeployScript(*env),
		b.ServiceKey().Address)

	// Add the keys argument, contract name, and code
	tx.AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys))
	tx.AddRawArgument(jsoncdc.MustEncode(CadenceString("FlowIDTableStaking")))
	tx.AddRawArgument(jsoncdc.MustEncode(cadenceCode))

	// Set the weekly payount amount and delegator cut percentage
	_ = tx.AddArgument(CadenceUFix64("1250000.0"))
	_ = tx.AddArgument(CadenceUFix64("0.08"))

	// Construct Array
	candidateLimitsArrayValues := make([]cadence.Value, 5)
	for i, limit := range candidateNodeLimits {
		candidateLimitsArrayValues[i] = cadence.NewUInt64(limit)
	}
	cadenceLimitArray := cadence.NewArray(candidateLimitsArrayValues).WithType(cadence.NewVariableSizedArrayType(cadence.NewUInt64Type()))

	_ = tx.AddArgument(cadenceLimitArray)

	// Submit the deployment transaction
	signAndSubmit(
		t, b, tx,
		[]flow.Address{},
		[]crypto.Signer{},
		false,
	)

	// Query the AccountCreated event to get the deployed address of the staking contract
	var idTableAddress flow.Address
	var i uint64
	i = 0
	for i < 1000 {
		results, _ := b.GetEventsByHeight(i, "flow.AccountCreated")

		for _, event := range results {
			if event.Type == flow.EventAccountCreated {
				idTableAddress = flow.Address(event.Value.Fields[0].(cadence.Address))
			}
		}
		i = i + 1
	}

	env.IDTableAddress = idTableAddress.Hex()

	// Transfer the fees admin to the staking contract account
	tx = flow.NewTransaction().
		SetScript(templates.GenerateTransferFeesAdminScript(*env)).
		SetGasLimit(9999).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(feesAddr).
		AddAuthorizer(idTableAddress)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{feesAddr, idTableAddress},
		[]crypto.Signer{IDTableSigner, IDTableSigner},
		false,
	)

	return idTableAddress, feesAddr
}

// / Used to verify staking info in tests
type StakingInfo struct {
	nodeID      string
	delegatorID uint32

	// tokens committed to stake for the next epoch
	tokensCommitted string

	// tokens staked during the current epoch
	tokensStaked string

	// tokens requested to unstake at the end of the current epoch
	tokensRequestedToUnstake string

	// tokens that are actively unstaking
	tokensUnstaking string

	// tokens that are unstaked and freely withdrawable
	tokensUnstaked string

	// tokens that have been rewarded by the protocol
	tokensRewarded string
}

// Verifies the staking information for the specified node or delegator
// If checking for a node, set delegatorID to 0
// if checking for a delegator, you must specify the nodeID that is being delegated to
// as well as the ID of the delegator for that node
func verifyStakingInfo(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	expectedStakingInfo StakingInfo,
) {

	// If verifying the node's staking information
	if expectedStakingInfo.delegatorID == 0 {

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensCommitted), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensStaked), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensRequestedToUnstake), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensUnstaking), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensUnstaked), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensRewarded), result)
	} else {

		// Verifies the delegator's information

		result := executeScriptAndCheck(t, b, templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID)), jsoncdc.MustEncode(cadence.UInt32(expectedStakingInfo.delegatorID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensCommitted), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID)), jsoncdc.MustEncode(cadence.UInt32(expectedStakingInfo.delegatorID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensStaked), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID)), jsoncdc.MustEncode(cadence.UInt32(expectedStakingInfo.delegatorID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensRequestedToUnstake), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID)), jsoncdc.MustEncode(cadence.UInt32(expectedStakingInfo.delegatorID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensUnstaking), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID)), jsoncdc.MustEncode(cadence.UInt32(expectedStakingInfo.delegatorID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensUnstaked), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(expectedStakingInfo.nodeID)), jsoncdc.MustEncode(cadence.UInt32(expectedStakingInfo.delegatorID))})
		assertEqual(t, CadenceUFix64(expectedStakingInfo.tokensRewarded), result)
	}
}

// Generate an array of string Node IDs
//
// parameter: numNodes: The number of nodes to generate IDs for
//
// returns: []string array of nodeIDs
//
//	[]cadence.Value array of only the collector node IDs, which are the first of every five IDs created
//	[]cadence.Vaule array of only the consensus node IDs, which are the second of every five IDs created
//	execution, verification, and access would be the next three, in that order, but their IDs aren't especially needed
func generateNodeIDs(numNodes int) ([]string, []cadence.Value, []cadence.Value) {
	// initialize the slices for all the IDs
	ids := make([]string, numNodes)
	collectorIDs := make([]cadence.Value, numNodes/6+1)
	consensusIDs := make([]cadence.Value, numNodes/7+1)

	// Create a new ID for each node
	for i := 0; i < numNodes; i++ {
		ids[i] = fmt.Sprintf("%064d", i)

		// If the ID is for a collector or consensus node, add the ID to the respective array
		if i%5 == 0 {
			collectorIDs[i/5] = CadenceString(ids[i])
		} else if i%5 == 1 {
			consensusIDs[i/5] = CadenceString(ids[i])
		}
	}

	return ids, collectorIDs, consensusIDs
}

// / Generates a key pair for staking, which uses the BLSBLS12381 signing algorithm
// / Also generates a key pair for networking, which uses the ECDSA_P256 signing algorithm
func generateKeysForNodeRegistration(t *testing.T) (crypto.PrivateKey, string, crypto.PrivateKey, string) {
	stakingPrivateKey, publicKey := generateKeys(t, flow_crypto.BLSBLS12381)
	stakingPublicKey := publicKey.String()
	stakingPublicKey = stakingPublicKey[2:]
	networkingPrivateKey, publicKey := generateKeys(t, flow_crypto.ECDSAP256)
	networkingPublicKey := publicKey.String()
	networkingPublicKey = networkingPublicKey[2:]

	return stakingPrivateKey, stakingPublicKey, networkingPrivateKey, networkingPublicKey

}

// / Generates staking and networking key pairs for the specified number of nodes
func generateManyNodeKeys(t *testing.T, numNodes int) ([]crypto.PrivateKey, []string, []crypto.PrivateKey, []string) {
	stakingPrivateKeys := make([]crypto.PrivateKey, numNodes)
	stakingPublicKeys := make([]string, numNodes)
	networkingPrivateKeys := make([]crypto.PrivateKey, numNodes)
	networkingPublicKeys := make([]string, numNodes)

	for i := 0; i < numNodes; i++ {
		stakingPrivateKey, stakingPublicKey, networkingPrivateKey, networkingPublicKey := generateKeysForNodeRegistration(t)
		stakingPrivateKeys[i] = stakingPrivateKey
		stakingPublicKeys[i] = stakingPublicKey
		networkingPrivateKeys[i] = networkingPrivateKey
		networkingPublicKeys[i] = networkingPublicKey
	}

	return stakingPrivateKeys, stakingPublicKeys, networkingPrivateKeys, networkingPublicKeys

}

// / Verifies that the EpochTotalRewardsPaid event was emmitted correctly with correct values
func verifyEpochTotalRewardsPaid(
	t *testing.T,
	b *emulator.Blockchain,
	idTableAddress flow.Address,
	expectedRewards EpochTotalRewardsPaid) {

	var emittedEvent EpochTotalRewardsPaidEvent

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := b.GetEventsByHeight(i, "A."+idTableAddress.String()+".FlowIDTableStaking.EpochTotalRewardsPaid")

		for _, event := range results {
			if event.Type == "A."+idTableAddress.String()+".FlowIDTableStaking.EpochTotalRewardsPaid" {
				emittedEvent = EpochTotalRewardsPaidEvent(event)
			}
		}

		i = i + 1
	}

	assertEqual(t, CadenceUFix64(expectedRewards.total), emittedEvent.Total())

	assertEqual(t, CadenceUFix64(expectedRewards.fromFees), emittedEvent.FromFees())

	assertEqual(t, CadenceUFix64(expectedRewards.minted), emittedEvent.Minted())

	assertEqual(t, CadenceUFix64(expectedRewards.feesBurned), emittedEvent.FeesBurned())
}

// Registers a node with the staking collection using the specified node information
// Caller specifies how many tokens the node already has committed and this function
// returns the new amount of committed tokens
// Used for testing
func registerNode(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	nodeID, networkingAddress, networkingKey, stakingKey string,
	amount, tokensCommitted interpreter.UFix64Value,
	role uint8,
	shouldFail bool,
) (
	newTokensCommitted interpreter.UFix64Value,
) {

	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateRegisterNodeScript(env),
		authorizer)

	_ = tx.AddArgument(CadenceString(nodeID))
	_ = tx.AddArgument(cadence.NewUInt8(role))
	_ = tx.AddArgument(CadenceString(networkingAddress))
	_ = tx.AddArgument(CadenceString(networkingKey))
	_ = tx.AddArgument(CadenceString(stakingKey))
	tokenAmount, err := cadence.NewUFix64(amount.String())
	require.NoError(t, err)
	_ = tx.AddArgument(tokenAmount)

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

// Registers a delegator with the staking collection using the specified node ID
// Caller specifies how many tokens the node already has committed and this function
// returns the new amount of committed tokens
// Used for testing
func registerDelegator(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	nodeID string,
	shouldFail bool,
) {

	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateRegisterDelegatorScript(env),
		authorizer)

	_ = tx.AddArgument(CadenceString(nodeID))
	tokenAmount, _ := cadence.NewUFix64("0.0")
	tx.AddArgument(tokenAmount)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{authorizer},
		[]crypto.Signer{signer},
		shouldFail,
	)
}

// Uses the staking admin to end the epoch, removing unapproved nodes and moving tokens between buckets
func endStakingMoveTokens(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	nodeIDs []string,
) {
	// End staking auction and epoch
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), authorizer)

	nodeIDsDict := generateCadenceNodeDictionary(nodeIDs)

	err := tx.AddArgument(nodeIDsDict)
	require.NoError(t, err)
	signAndSubmit(
		t, b, tx,
		[]flow.Address{authorizer},
		[]crypto.Signer{signer},
		false,
	)
}

// / Registers the specified number of nodes for staking with the specified IDs
// / Does an even distrubution of node roles across the array of IDs in this order, repeating:
// / collection, consensus, execution, verification, access
func registerNodesForStaking(
	t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizers []flow.Address,
	signers []crypto.Signer,
	stakingKeys []string,
	networkingkeys []string,
	ids []string) {

	// If the number of authorizers is not the same as the number of signers, fail
	if len(authorizers) != len(signers) ||
		len(authorizers) != len(ids) ||
		len(authorizers) != len(stakingKeys) ||
		len(authorizers) != len(networkingkeys) {
		t.Fail()
	}

	// set the amount of tokens as the 1.35M, which is greater than the minimum for all the nodes
	var amountToCommit interpreter.UFix64Value = 135000000000000
	var committed interpreter.UFix64Value = 0

	// iterate through all the authorizers and execute the register node transaction
	i := 0
	for _, authorizer := range authorizers {

		registerNode(t, b, env,
			authorizer,
			signers[i],
			ids[i],
			fmt.Sprintf("%0128d", i),
			networkingkeys[i],
			stakingKeys[i],
			amountToCommit,
			committed,
			uint8((i%5)+1),
			false)

		i++
	}
}

// Commit new tokens for a registered node
// The caller can provide the nodes currently committed tokens
// in order to have the newly committed tokens returned
func commitNewTokens(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	amount, tokensCommitted interpreter.UFix64Value,
	shouldFail bool,
) (
	// the new amount of tokens that this node has committed
	newTokensCommitted interpreter.UFix64Value,
) {

	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateStakeNewTokensScript(env),
		authorizer)

	tokenAmount, err := cadence.NewUFix64(amount.String())
	require.NoError(t, err)
	err = tx.AddArgument(tokenAmount)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{authorizer},
		[]crypto.Signer{signer},
		shouldFail,
	)

	if !shouldFail {
		newTokensCommitted = tokensCommitted.Plus(stubInterpreter(), amount, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
	} else {
		newTokensCommitted = tokensCommitted
	}

	return
}

// Commits tokens from the node's unstaked bucket
func commitUnstaked(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	amount, tokensCommitted, tokensUnstaked interpreter.UFix64Value,
	shouldFail bool,
) (
	newTokensCommitted interpreter.UFix64Value,
	newTokensUnstaked interpreter.UFix64Value,
) {

	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateStakeUnstakedTokensScript(env),
		authorizer)

	tokenAmount, err := cadence.NewUFix64(amount.String())
	require.NoError(t, err)
	err = tx.AddArgument(tokenAmount)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{authorizer},
		[]crypto.Signer{signer},
		shouldFail,
	)

	if !shouldFail {
		newTokensCommitted = tokensCommitted.Plus(stubInterpreter(), amount, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		newTokensUnstaked = tokensUnstaked.Minus(stubInterpreter(), amount, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
	} else {
		newTokensCommitted = tokensCommitted
		newTokensUnstaked = tokensUnstaked
	}

	return
}

// Commits tokens from the node's rewards bucket
func commitRewarded(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	amount, tokensCommitted, tokensRewarded interpreter.UFix64Value,
	shouldFail bool,
) (
	newTokensCommitted, newTokensRewarded interpreter.UFix64Value,
) {

	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateStakeRewardedTokensScript(env),
		authorizer)

	tokenAmount, err := cadence.NewUFix64(amount.String())
	require.NoError(t, err)
	err = tx.AddArgument(tokenAmount)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{authorizer},
		[]crypto.Signer{signer},
		shouldFail,
	)

	if !shouldFail {
		newTokensRewarded = tokensRewarded.Minus(stubInterpreter(), amount, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		newTokensCommitted = tokensCommitted.Plus(stubInterpreter(), amount, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
	} else {
		newTokensRewarded = tokensRewarded
		newTokensCommitted = tokensCommitted
	}

	return
}

// Requests to unstake tokens that are currently staked by the node
func requestUnstaking(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	amount, tokensCommitted, tokensUnstaked, request interpreter.UFix64Value,
	shouldFail bool,
) (
	newTokensCommitted, newTokensUnstaked, newRequest interpreter.UFix64Value,
) {

	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateUnstakeTokensScript(env),
		authorizer)

	tokenAmount, err := cadence.NewUFix64(amount.String())
	require.NoError(t, err)
	err = tx.AddArgument(tokenAmount)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{authorizer},
		[]crypto.Signer{signer},
		shouldFail,
	)

	if !shouldFail {
		if tokensCommitted > amount {
			newTokensCommitted = tokensCommitted.Minus(stubInterpreter(), amount, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
			newTokensUnstaked = tokensUnstaked.Plus(stubInterpreter(), amount, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
			newRequest = request
		} else {
			newRequest = request.Plus(stubInterpreter(), amount.Minus(stubInterpreter(), tokensCommitted, interpreter.EmptyLocationRange), interpreter.EmptyLocationRange).(interpreter.UFix64Value)
			newTokensUnstaked = tokensUnstaked.Plus(stubInterpreter(), tokensCommitted, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
			newTokensCommitted = 0
		}
	} else {
		newRequest = request
		newTokensUnstaked = tokensUnstaked
		newTokensCommitted = tokensCommitted
	}

	return
}

// Uses the staking admin to execute the pay rewards transaction
func payRewards(
	isDelegator bool,
	totalPayout, totalStaked, cut, staked interpreter.UFix64Value,
) (
	rewards, delegateeRewards interpreter.UFix64Value,
) {
	calculatedRewards := totalPayout.Div(stubInterpreter(), totalStaked, interpreter.EmptyLocationRange).Mul(stubInterpreter(), staked, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

	if isDelegator {
		delegateeRewards = calculatedRewards.Mul(stubInterpreter(), cut, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		rewards = calculatedRewards.Minus(stubInterpreter(), delegateeRewards, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

	} else {
		delegateeRewards = 0
		rewards = calculatedRewards
	}

	return
}

// Uses the staking admin to call the moveTokens transaction
func moveTokens(committed, staked, requested, unstaking, unstaked, totalStaked interpreter.UFix64Value,
) (
	newCommitted, newStaked, newRequested, newUnstaking, newUnstaked, newTotalStaked interpreter.UFix64Value,
) {
	newTotalStaked = totalStaked.Plus(stubInterpreter(), committed, interpreter.EmptyLocationRange).Minus(stubInterpreter(), requested, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

	newCommitted = 0

	newStaked = staked.Plus(stubInterpreter(), committed, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

	newUnstaked = unstaked.Plus(stubInterpreter(), unstaking, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

	newUnstaking = requested

	newStaked = newStaked.Minus(stubInterpreter(), requested, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

	newRequested = 0

	return
}

// Generates a Cadence {String: Bool} dictionary from an array of node IDs
func generateCadenceNodeDictionary(nodeIDs []string) cadence.Value {

	// Construct Array
	nodeIDsCadenceArrayValues := make([]cadence.Value, len(nodeIDs))

	// Construct Boolean
	trueBool := cadence.NewBool(true)

	keyValuePairArray := make([]cadence.KeyValuePair, len(nodeIDs))

	for i, nodeID := range nodeIDs {
		cadenceNodeID, _ := cadence.NewString(nodeID)

		nodeIDsCadenceArrayValues[i] = cadenceNodeID

		pair := cadence.KeyValuePair{Key: cadenceNodeID, Value: trueBool}

		keyValuePairArray[i] = pair
	}

	return cadence.NewDictionary(keyValuePairArray).WithType(cadence.NewDictionaryType(cadence.NewStringType(), cadence.NewBoolType()))
}

// assertApprovedListEquals asserts the FlowIDTableStaking approved list matches
// the given node ID list
// The approved list is guaranteed to only have unique values
func assertApprovedListEquals(
	t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	expected cadence.Value, // [String]
) {
	result := executeScriptAndCheck(t, b, templates.GenerateGetApprovedNodesScript(env), nil).(cadence.Array).Values
	assertCadenceNodeArrayElementsEqual(t, expected.(cadence.Array).Values, result)
}

type CandidateNodes struct {
	collector    []string
	consensus    []string
	execution    []string
	verification []string
	access       []string
}

// assertCandidateNodeListEquals asserts the FlowIDTableStaking candidate node list matches
// the given node ID list
func assertCandidateNodeListEquals(
	t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	expectedCandidateNodeList CandidateNodes,
) {

	result := executeScriptAndCheck(t, b, templates.GenerateGetCandidateNodesScript(env), nil).(cadence.Dictionary)

	for _, rolePair := range result.Pairs {

		actualNodeIDDict := rolePair.Value.(cadence.Dictionary).Pairs

		if rolePair.Key == cadence.NewUInt8(1) {
			expectedNodeIDDict := generateCadenceNodeDictionary(expectedCandidateNodeList.collector).(cadence.Dictionary).Pairs

			assertCadenceNodeDictionaryKeysAndValuesEqual(t, expectedNodeIDDict, actualNodeIDDict)

		} else if rolePair.Key == cadence.NewUInt8(2) {
			expectedNodeIDDict := generateCadenceNodeDictionary(expectedCandidateNodeList.consensus).(cadence.Dictionary).Pairs

			assertCadenceNodeDictionaryKeysAndValuesEqual(t, expectedNodeIDDict, actualNodeIDDict)

		} else if rolePair.Key == cadence.NewUInt8(3) {
			expectedNodeIDDict := generateCadenceNodeDictionary(expectedCandidateNodeList.execution).(cadence.Dictionary).Pairs

			assertCadenceNodeDictionaryKeysAndValuesEqual(t, expectedNodeIDDict, actualNodeIDDict)

		} else if rolePair.Key == cadence.NewUInt8(4) {
			expectedNodeIDDict := generateCadenceNodeDictionary(expectedCandidateNodeList.verification).(cadence.Dictionary).Pairs

			assertCadenceNodeDictionaryKeysAndValuesEqual(t, expectedNodeIDDict, actualNodeIDDict)

		} else if rolePair.Key == cadence.NewUInt8(5) {
			expectedNodeIDDict := generateCadenceNodeDictionary(expectedCandidateNodeList.access).(cadence.Dictionary).Pairs

			assertCadenceNodeDictionaryKeysAndValuesEqual(t, expectedNodeIDDict, actualNodeIDDict)

		}

	}

}

// assertCandidateLimitsEquals asserts the FlowIDTableStaking
// candidate node limits matches the given limit list
func assertCandidateLimitsEquals(
	t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	expectedCandidateNodeList []uint64,
) {

	result := executeScriptAndCheck(t, b, templates.GenerateGetCandidateLimitsScript(env), nil).(cadence.Dictionary)

	for _, rolePair := range result.Pairs {

		if rolePair.Key == cadence.NewUInt8(1) {

			assert.Equal(t, cadence.NewUInt64(expectedCandidateNodeList[0]), rolePair.Value)

		} else if rolePair.Key == cadence.NewUInt8(2) {

			assert.Equal(t, cadence.NewUInt64(expectedCandidateNodeList[1]), rolePair.Value)

		} else if rolePair.Key == cadence.NewUInt8(3) {

			assert.Equal(t, cadence.NewUInt64(expectedCandidateNodeList[2]), rolePair.Value)

		} else if rolePair.Key == cadence.NewUInt8(4) {

			assert.Equal(t, cadence.NewUInt64(expectedCandidateNodeList[3]), rolePair.Value)

		} else if rolePair.Key == cadence.NewUInt8(5) {

			assert.Equal(t, cadence.NewUInt64(expectedCandidateNodeList[4]), rolePair.Value)

		}
	}
}

// assertRoleCountsEquals asserts the FlowIDTableStaking
// role counts matches the given list
func assertRoleCountsEquals(
	t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	expectedRoleCountsList []uint16,
) {

	result := executeScriptAndCheck(t, b, templates.GenerateGetRoleCountsScript(env), nil).(cadence.Dictionary)

	for _, rolePair := range result.Pairs {

		if rolePair.Key == cadence.NewUInt8(1) {

			assert.Equal(t, cadence.NewUInt16(expectedRoleCountsList[0]), rolePair.Value)

		} else if rolePair.Key == cadence.NewUInt8(2) {

			assert.Equal(t, cadence.NewUInt16(expectedRoleCountsList[1]), rolePair.Value)

		} else if rolePair.Key == cadence.NewUInt8(3) {

			assert.Equal(t, cadence.NewUInt16(expectedRoleCountsList[2]), rolePair.Value)

		} else if rolePair.Key == cadence.NewUInt8(4) {

			assert.Equal(t, cadence.NewUInt16(expectedRoleCountsList[3]), rolePair.Value)

		} else if rolePair.Key == cadence.NewUInt8(5) {

			assert.Equal(t, cadence.NewUInt16(expectedRoleCountsList[4]), rolePair.Value)

		}
	}
}

// / Sets the role slot limits to the specified values
func setNodeRoleSlotLimits(
	t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	idTableAddress flow.Address,
	idTableSigner crypto.Signer,
	slotLimits [5]uint16,
) {
	// set the slot limits
	cadenceSlotLimits := make([]cadence.Value, 5)
	for i := 0; i < 5; i++ {
		cadenceSlotLimits[i] = cadence.NewUInt16(slotLimits[i])
	}

	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetSlotLimitsScript(env), idTableAddress)

	err := tx.AddArgument(cadence.NewArray(cadenceSlotLimits))
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{idTableSigner},
		false,
	)
}

// Asserts that {String: Bool} dictionaries of node IDs from the staking contract
// have the same keys and values and have the same length
// We have no guarantees about the order of elements, so we can't check that
func assertCadenceNodeDictionaryKeysAndValuesEqual(t *testing.T, expected, actual []cadence.KeyValuePair) bool {
	assert.Len(t, actual, len(expected))

	for _, resultPair := range actual {
		found := false
		for _, expectedPair := range expected {
			if resultPair.Key == expectedPair.Key && resultPair.Value == expectedPair.Value {
				found = true
			}
		}

		// One of the result values was not found in the expected list
		if !assert.True(t, found) {
			message := fmt.Sprintf(
				"Dictionaries are not equal: \nexpected: %s\nactual  : %s",
				expected,
				actual,
			)

			return assert.Fail(t, message)
		}
	}
	return true
}

// Asserts that arrays of node IDs from the staking contract
// have the same elements and have the same length
// We have no guarantees about the order of elements, so we can't check that
func assertCadenceNodeArrayElementsEqual(t *testing.T, expected, actual []cadence.Value) bool {
	assert.Len(t, actual, len(expected))

	for _, resultVal := range actual {
		found := false
		for _, expectedVal := range expected {
			if resultVal == expectedVal {
				found = true
			}
		}

		// One of the result values was not found in the expected list
		if !assert.True(t, found) {
			message := fmt.Sprintf(
				"Arrays are not equal: \nexpected: %s\nactual  : %s",
				expected,
				actual,
			)

			return assert.Fail(t, message)
		}
	}
	return true
}
