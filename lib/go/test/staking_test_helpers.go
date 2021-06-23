package test

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/cadence/runtime/interpreter"
	emulator "github.com/onflow/flow-emulator"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

// Defines utility functions that are used for testing the staking contract
// such as deploying the contract, performing staking operations,
// and verifying staking information for nodes and delegators

// Deploys the FlowIDTableStaking contract to a new account with the provided key
//
// parameter: latest: Indicates if the contract should be the latest version.
//                    This is only set to false when testing staking contract upgrades
//
func deployStakingContract(t *testing.T, b *emulator.Blockchain, IDTableAccountKey *flow.AccountKey, env templates.Environment, latest bool) flow.Address {

	// Get the code byte-array for the staking contract
	IDTableCode := contracts.FlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress, latest)
	cadenceCode := bytesToCadenceArray(IDTableCode)

	// create the public key array for the staking account
	publicKeys := make([]cadence.Value, 1)
	publicKeys[0] = bytesToCadenceArray(IDTableAccountKey.Encode())
	cadencePublicKeys := cadence.NewArray(publicKeys)

	// Create the deployment transaction that transfers a FlowToken minter
	// to the new account and deploys the IDTableStaking contract
	tx := createTxWithTemplateAndAuthorizer(b,
		templates.GenerateTransferMinterAndDeployScript(env),
		b.ServiceKey().Address)

	// Add the keys argument, contract name, and code
	tx.AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys))
	tx.AddRawArgument(jsoncdc.MustEncode(cadence.String("FlowIDTableStaking")))
	tx.AddRawArgument(jsoncdc.MustEncode(cadenceCode))

	// Set the weekly payount amount and delegator cut percentage
	_ = tx.AddArgument(CadenceUFix64("1250000.0"))
	_ = tx.AddArgument(CadenceUFix64("0.08"))

	// Submit the deployment transaction
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{b.ServiceKey().Signer()},
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

	return idTableAddress
}

/// Used to verify staking info in tests
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
//
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
//          []cadence.Value array of only the collector node IDs, which are the first of every five IDs created
//          []cadence.Vaule array of only the consensus node IDs, which are the second of every five IDs created
//          execution, verification, and access would be the next three, in that order, but their IDs aren't especially needed
func generateNodeIDs(numNodes int) ([]string, []cadence.Value, []cadence.Value) {
	// initialize the slices for all the IDs
	ids := make([]string, numNodes)
	collectorIDs := make([]cadence.Value, numNodes/5+1)
	consensusIDs := make([]cadence.Value, numNodes/5+1)

	// Create a new ID for each node
	for i := 0; i < numNodes; i++ {
		ids[i] = fmt.Sprintf("%064d", i)

		// If the ID is for a collector or consensus node, add the ID to the respective array
		if i == 0 {
			collectorIDs[i/5] = cadence.String(ids[i])
		} else if i == 1 {
			consensusIDs[i/5] = cadence.String(ids[i])
		}
	}

	return ids, collectorIDs, consensusIDs
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

	_ = tx.AddArgument(cadence.String(nodeID))
	_ = tx.AddArgument(cadence.NewUInt8(role))
	_ = tx.AddArgument(cadence.String(networkingAddress))
	_ = tx.AddArgument(cadence.String(networkingKey))
	_ = tx.AddArgument(cadence.String(stakingKey))
	tokenAmount, err := cadence.NewUFix64(amount.String())
	require.NoError(t, err)
	_ = tx.AddArgument(tokenAmount)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		shouldFail,
	)

	if !shouldFail {
		newTokensCommitted = tokensCommitted.Plus(amount).(interpreter.UFix64Value)
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

	_ = tx.AddArgument(cadence.String(nodeID))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		shouldFail,
	)
}

// Uses the staking admin to end the epoch, removing unapproved nodes and moving tokens between buckets
func endStakingMoveTokens(t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizer flow.Address,
	signer crypto.Signer,
	nodeIDs []cadence.Value,
) {
	// End staking auction and epoch
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), authorizer)

	err := tx.AddArgument(cadence.NewArray(nodeIDs))
	require.NoError(t, err)
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		false,
	)
}

/// Registers the specified number of nodes for staking with the specified IDs
/// Does an even distrubution of node roles across the array of IDs in this order, repeating:
/// collection, consensus, execution, verification, access
//
func registerNodesForStaking(
	t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	authorizers []flow.Address,
	signers []crypto.Signer,
	ids []string) {

	// If the number of authorizers is not the same as the number of signers, fail
	if len(authorizers) != len(signers) ||
		len(authorizers) != len(ids) {
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
			fmt.Sprintf("%0128d", i),
			fmt.Sprintf("%0192d", i),
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
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		shouldFail,
	)

	if !shouldFail {
		newTokensCommitted = tokensCommitted.Plus(amount).(interpreter.UFix64Value)
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
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		shouldFail,
	)

	if !shouldFail {
		newTokensCommitted = tokensCommitted.Plus(amount).(interpreter.UFix64Value)
		newTokensUnstaked = tokensUnstaked.Minus(amount).(interpreter.UFix64Value)
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
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		shouldFail,
	)

	if !shouldFail {
		newTokensRewarded = tokensRewarded.Minus(amount).(interpreter.UFix64Value)
		newTokensCommitted = tokensCommitted.Plus(amount).(interpreter.UFix64Value)
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
		[]flow.Address{b.ServiceKey().Address, authorizer},
		[]crypto.Signer{b.ServiceKey().Signer(), signer},
		shouldFail,
	)

	if !shouldFail {
		if tokensCommitted > amount {
			newTokensCommitted = tokensCommitted.Minus(amount).(interpreter.UFix64Value)
			newTokensUnstaked = tokensUnstaked.Plus(amount).(interpreter.UFix64Value)
			newRequest = request
		} else {
			newRequest = request.Plus(amount.Minus(tokensCommitted)).(interpreter.UFix64Value)
			newTokensUnstaked = tokensUnstaked.Plus(tokensCommitted).(interpreter.UFix64Value)
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
	calculatedRewards := totalPayout.Div(totalStaked).Mul(staked).(interpreter.UFix64Value)

	if isDelegator {
		delegateeRewards = calculatedRewards.Mul(cut).(interpreter.UFix64Value)
		rewards = calculatedRewards.Minus(delegateeRewards).(interpreter.UFix64Value)

	} else {
		delegateeRewards = 0
		rewards = calculatedRewards
	}

	return
}

// Uses the staking admin to call the moveTokens transaction
//
func moveTokens(committed, staked, requested, unstaking, unstaked, totalStaked interpreter.UFix64Value,
) (
	newCommitted, newStaked, newRequested, newUnstaking, newUnstaked, newTotalStaked interpreter.UFix64Value,
) {
	newTotalStaked = totalStaked.Plus(committed).Minus(requested).(interpreter.UFix64Value)

	newCommitted = 0

	newStaked = staked.Plus(committed).(interpreter.UFix64Value)

	newUnstaked = unstaked.Plus(unstaking).(interpreter.UFix64Value)

	newUnstaking = requested

	newStaked = newStaked.Minus(requested).(interpreter.UFix64Value)

	newRequested = 0

	return
}
