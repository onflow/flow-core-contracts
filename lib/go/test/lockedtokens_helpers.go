package test

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	emulator "github.com/onflow/flow-emulator"
	ft_templates "github.com/onflow/flow-ft/lib/go/templates"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"

	sdktemplates "github.com/onflow/flow-go-sdk/templates"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

// Shared account Registered event

type SharedAccountRegisteredEvent interface {
	Address() flow.Address
}

type sharedAccountRegisteredEvent flow.Event

var _ SharedAccountRegisteredEvent = (*sharedAccountRegisteredEvent)(nil)

// Address returns the address of the newly-created account.
func (evt sharedAccountRegisteredEvent) Address() flow.Address {
	return flow.BytesToAddress(evt.Value.Fields[0].(cadence.Address).Bytes())
}

// Unlocked account Registered event

type UnlockedAccountRegisteredEvent interface {
	Address() flow.Address
}

type unlockedAccountRegisteredEvent flow.Event

var _ UnlockedAccountRegisteredEvent = (*unlockedAccountRegisteredEvent)(nil)

// Address returns the address of the newly-created account.
func (evt unlockedAccountRegisteredEvent) Address() flow.Address {
	return flow.BytesToAddress(evt.Value.Fields[0].(cadence.Address).Bytes())
}

// Deploy the locked tokens contract
// and mint tokens for the locked tokens admin account
func deployLockedTokensContract(
	t *testing.T,
	b *emulator.Blockchain,
	IDTableAddr, proxyAddr flow.Address,
	lockedTokensAccountKey *flow.AccountKey,
) flow.Address {

	// Get the code of the locked tokens contract
	// with the import addresses replaced
	lockedTokensCode := contracts.FlowLockedTokens(
		emulatorFTAddress,
		emulatorFlowTokenAddress,
		IDTableAddr.Hex(),
		proxyAddr.Hex(),
		b.ServiceKey().Address.String(),
	)
	// Encode the contract as a Cadence string
	cadenceCode := cadence.NewString(hex.EncodeToString(lockedTokensCode))

	// Create the locked tokens account key array and a key
	publicKeys := make([]cadence.Value, 1)
	publicKeys[0] = bytesToCadenceArray(lockedTokensAccountKey.Encode())
	cadencePublicKeys := cadence.NewArray(publicKeys)

	// Create the transaction template to deploy the locked tokens contract
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDeployLockedTokens(), b.ServiceKey().Address)
	// Add the arguments for contract name, contract code, and public keys for the account
	tx.AddRawArgument(jsoncdc.MustEncode(cadence.NewString("LockedTokens")))
	tx.AddRawArgument(jsoncdc.MustEncode(cadenceCode))
	tx.AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys))

	// Sign and submit the transaction
	err := tx.SignEnvelope(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().Signer())
	require.NoError(t, err)
	err = b.AddTransaction(*tx)
	require.NoError(t, err)
	result, err := b.ExecuteNextTransaction()
	require.NoError(t, err)
	require.NoError(t, result.Error)

	// Search emitted events from the transaction result
	// to find the address of the locked tokens contract
	var lockedTokensAddr flow.Address

	for _, event := range result.Events {
		if event.Type == flow.EventAccountCreated {
			accountCreatedEvent := flow.AccountCreatedEvent(event)
			lockedTokensAddr = accountCreatedEvent.Address()
			break
		}
	}

	// Commit the result as a block
	_, err = b.CommitBlock()
	require.NoError(t, err)

	// Mint tokens for the locked tokens admin
	script := ft_templates.GenerateMintTokensScript(
		flow.HexToAddress(emulatorFTAddress),
		flow.HexToAddress(emulatorFlowTokenAddress),
		"FlowToken",
	)
	tx = createTxWithTemplateAndAuthorizer(b, script, b.ServiceKey().Address)
	_ = tx.AddArgument(cadence.NewAddress(lockedTokensAddr))
	_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{b.ServiceKey().Signer()},
		false,
	)

	return lockedTokensAddr
}

/****************** Staking Collection utilities ************************/

type DelegatorIDs struct {
	nodeID string
	id     uint32
}

/// Used to verify staking collection info in tests
type StakingCollectionInfo struct {
	accountAddress     string
	unlockedBalance    string
	lockedBalance      string
	unlockedTokensUsed string
	lockedTokensUsed   string
	unlockLimit        string
	nodes              []string
	delegators         []DelegatorIDs
}

// Deploys the staking collection contract to the specified lockedTokensAddress
// because the staking collection needs to be deployed to the same account as LockedTokens
func deployCollectionContract(t *testing.T, b *emulator.Blockchain,
	idTableAddress,
	stakingProxyAddress,
	lockedTokensAddress flow.Address,
	lockedTokensSigner crypto.Signer,
	env *templates.Environment) {

	// Get the test version of the staking collection contract that has all public fields
	// for testing purposes
	FlowStakingCollectionCode := contracts.TESTFlowStakingCollection(emulatorFTAddress, emulatorFlowTokenAddress, idTableAddress.String(), stakingProxyAddress.String(), lockedTokensAddress.String(), b.ServiceKey().Address.String())
	FlowStakingCollectionByteCode := cadence.NewString(hex.EncodeToString(FlowStakingCollectionCode))

	// Deploy the staking collection contract
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDeployStakingCollectionScript(), lockedTokensAddress).
		AddRawArgument(jsoncdc.MustEncode(cadence.NewString("FlowStakingCollection"))).
		AddRawArgument(jsoncdc.MustEncode(FlowStakingCollectionByteCode))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, lockedTokensAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), lockedTokensSigner},
		false,
	)
}

// Deploys the staking contract, staking proxy, locked tokens contract,
// and staking collection contract.
func deployAllCollectionContracts(t *testing.T,
	b *emulator.Blockchain,
	accountKeys *test.AccountKeys,
	env *templates.Environment) crypto.Signer {

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	// DEPLOY IDTableStaking
	var idTableAddress = deployStakingContract(t, b, IDTableAccountKey, *env, true)

	env.IDTableAddress = idTableAddress.Hex()

	// DEPLOY StakingProxy

	// Deploy the StakingProxy contract
	stakingProxyCode := contracts.FlowStakingProxy()
	stakingProxyAddress, err := b.CreateAccount(nil, []sdktemplates.Contract{
		{
			Name:   "StakingProxy",
			Source: string(stakingProxyCode),
		},
	})
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}
	_, err = b.CommitBlock()
	assert.NoError(t, err)

	lockedTokensAccountKey, lockedTokensSigner := accountKeys.NewWithSigner()
	lockedTokensAddress := deployLockedTokensContract(t, b, idTableAddress, stakingProxyAddress, lockedTokensAccountKey)
	env.StakingProxyAddress = stakingProxyAddress.Hex()
	env.LockedTokensAddress = lockedTokensAddress.Hex()

	// DEPLOY StakingCollection

	deployCollectionContract(t, b, idTableAddress, stakingProxyAddress, lockedTokensAddress, lockedTokensSigner, env)

	return IDTableSigner
}

/// Creates a new pair of normal and locked accounts
/// with their balances initialized to the provided values
func createLockedAccountPairWithBalances(
	t *testing.T,
	b *emulator.Blockchain,
	accountKeys *test.AccountKeys,
	env templates.Environment,
	lockedBalance, unlockedBalance string,
) (flow.Address, flow.Address, crypto.Signer) {

	newUserKey, newUserSigner := accountKeys.NewWithSigner()

	adminAccountKey := accountKeys.New()

	adminPublicKey := bytesToCadenceArray(adminAccountKey.Encode())
	newUserPublicKey := bytesToCadenceArray(newUserKey.Encode())

	var newUserSharedAddress flow.Address
	var newUserAddress flow.Address

	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateSharedAccountScript(env), b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
		AddRawArgument(jsoncdc.MustEncode(newUserPublicKey)).
		AddRawArgument(jsoncdc.MustEncode(newUserPublicKey))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{b.ServiceKey().Signer()},
		false,
	)

	createAccountsTxResult, err := b.GetTransactionResult(tx.ID())
	assert.NoError(t, err)
	assertEqual(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

	for _, event := range createAccountsTxResult.Events {
		if event.Type == fmt.Sprintf("A.%s.LockedTokens.SharedAccountRegistered", env.LockedTokensAddress) {
			// needs work
			sharedAccountCreatedEvent := sharedAccountRegisteredEvent(event)
			newUserSharedAddress = sharedAccountCreatedEvent.Address()
			break
		}
	}

	for _, event := range createAccountsTxResult.Events {
		if event.Type == fmt.Sprintf("A.%s.LockedTokens.UnlockedAccountRegistered", env.LockedTokensAddress) {
			// needs work
			unlockedAccountCreatedEvent := unlockedAccountRegisteredEvent(event)
			newUserAddress = unlockedAccountCreatedEvent.Address()
			break
		}
	}

	if lockedBalance != "0.0" {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositLockedTokensScript(env), b.ServiceKey().Address)
		_ = tx.AddArgument(cadence.NewAddress(newUserSharedAddress))
		_ = tx.AddArgument(CadenceUFix64(lockedBalance))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// check balance of locked account
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(newUserAddress))})
		assertEqual(t, CadenceUFix64(lockedBalance), result)
	}

	if unlockedBalance != "0.0" {
		mintTokensForAccount(t, b, newUserAddress, unlockedBalance)
	}

	return newUserAddress, newUserSharedAddress, newUserSigner
}

func randomHex(n int) (string, error) {
	bytes := make([]byte, n)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

func registerStakingCollectionNodesAndDelegators(
	t *testing.T,
	b *emulator.Blockchain,
	accountKeys *test.AccountKeys,
	env templates.Environment,
	lockedBalance, unlockedBalance string,
) (flow.Address, flow.Address, crypto.Signer, string, string) {

	// Create a locked account pair with tokens in both accounts
	newUserAddress, newUserSharedAddress, newUserSigner := createLockedAccountPairWithBalances(
		t, b,
		accountKeys,
		env,
		lockedBalance, unlockedBalance)

	userNodeID1, _ := randomHex(32)
	userNodeID2, _ := randomHex(32)

	nodeAddr1, _ := randomHex(32)
	nodeNetworkKey1, _ := randomHex(64)
	nodStakingKey1, _ := randomHex(96)

	// Register a node and a delegator in the locked account
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterLockedNodeScript(env), newUserAddress)
	_ = tx.AddArgument(cadence.NewString(userNodeID1))
	_ = tx.AddArgument(cadence.NewUInt8(4))
	_ = tx.AddArgument(cadence.NewString(nodeAddr1))
	_ = tx.AddArgument(cadence.NewString(nodeNetworkKey1))
	_ = tx.AddArgument(cadence.NewString(nodStakingKey1))
	_ = tx.AddArgument(CadenceUFix64("320000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, newUserAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), newUserSigner},
		false,
	)

	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateLockedDelegatorScript(env), newUserAddress)
	_ = tx.AddArgument(cadence.NewString(userNodeID1))
	_ = tx.AddArgument(CadenceUFix64("50000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, newUserAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), newUserSigner},
		false,
	)

	// add a staking collection to the main account
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), newUserAddress)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, newUserAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), newUserSigner},
		false,
	)

	nodeAddr2, _ := randomHex(32)
	nodeNetworkKey2, _ := randomHex(64)
	nodStakingKey2, _ := randomHex(96)

	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterNode(env), newUserAddress)
	_ = tx.AddArgument(cadence.NewString(userNodeID2))
	_ = tx.AddArgument(cadence.NewUInt8(2))
	_ = tx.AddArgument(cadence.NewString(nodeAddr2))
	_ = tx.AddArgument(cadence.NewString(nodeNetworkKey2))
	_ = tx.AddArgument(cadence.NewString(nodStakingKey2))
	_ = tx.AddArgument(CadenceUFix64("500000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, newUserAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), newUserSigner},
		false,
	)

	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterDelegator(env), newUserAddress)
	_ = tx.AddArgument(cadence.NewString(userNodeID2))
	_ = tx.AddArgument(CadenceUFix64("500000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, newUserAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), newUserSigner},
		false,
	)

	return newUserAddress, newUserSharedAddress, newUserSigner, userNodeID1, userNodeID2
}

func verifyStakingCollectionInfo(
	t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	expectedInfo StakingCollectionInfo,
) {
	// check balance of unlocked account
	result := executeScriptAndCheck(t, b, ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(flow.HexToAddress(expectedInfo.accountAddress)))})
	assertEqual(t, CadenceUFix64(expectedInfo.unlockedBalance), result)

	// check balance of locked account if it exists
	if len(expectedInfo.lockedBalance) > 0 {
		result = executeScriptAndCheck(t, b, templates.GenerateGetLockedAccountBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(flow.HexToAddress(expectedInfo.accountAddress)))})
		assertEqual(t, CadenceUFix64(expectedInfo.lockedBalance), result)
	}

	// check unlocked tokens used
	result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetUnlockedTokensUsedScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(flow.HexToAddress(expectedInfo.accountAddress)))})
	assertEqual(t, CadenceUFix64(expectedInfo.unlockedTokensUsed), result)

	// check locked tokens used
	result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetLockedTokensUsedScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(flow.HexToAddress(expectedInfo.accountAddress)))})
	assertEqual(t, CadenceUFix64(expectedInfo.lockedTokensUsed), result)

	// Check unlock limit of the shared account if it exists
	if len(expectedInfo.unlockLimit) > 0 {
		result = executeScriptAndCheck(t, b,
			templates.GenerateGetUnlockLimitScript(env),
			[][]byte{
				jsoncdc.MustEncode(cadence.Address(flow.HexToAddress(expectedInfo.accountAddress))),
			},
		)
		assertEqual(t, CadenceUFix64(expectedInfo.unlockLimit), result)
	}

	// check node IDs
	result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetNodeIDsScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(flow.HexToAddress(expectedInfo.accountAddress)))})
	nodeArray := result.(cadence.Array).Values
	i := 0
	for _, nodeID := range expectedInfo.nodes {
		assertEqual(t, cadence.NewString(nodeID), nodeArray[i])
		i = i + 1
	}

	// check delegator IDs
	result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetDelegatorIDsScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(flow.HexToAddress(expectedInfo.accountAddress)))})
	delegatorArray := result.(cadence.Array).Values
	i = 0
	for _, delegator := range expectedInfo.delegators {
		nodeID := delegatorArray[i].(cadence.Struct).Fields[0]
		delegatorID := delegatorArray[i].(cadence.Struct).Fields[1]
		assertEqual(t, cadence.NewString(delegator.nodeID), nodeID)
		assertEqual(t, cadence.NewUInt32(delegator.id), delegatorID)
		i = i + 1
	}
}
