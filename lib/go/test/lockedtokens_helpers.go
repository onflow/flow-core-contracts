package test

import (
	"encoding/hex"
	"fmt"
	"testing"

	"github.com/onflow/flow-emulator/types"

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

// Contains utility functions that are used for testing the locked tokens
// contracts with the flow emulator, as

/************ Event Definitions ***************/

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
	adminAddress flow.Address,
	adminSigner crypto.Signer,
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
	cadenceCode := CadenceString(hex.EncodeToString(lockedTokensCode))

	// Create the locked tokens account key array and a key
	publicKeys := make([]cadence.Value, 1)
	publicKeys[0] = bytesToCadenceArray(lockedTokensAccountKey.Encode())
	cadencePublicKeys := cadence.NewArray(publicKeys)

	// Create the transaction template to deploy the locked tokens contract
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDeployLockedTokens(), adminAddress)
	// Add the arguments for contract name, contract code, and public keys for the account
	tx.AddRawArgument(jsoncdc.MustEncode(CadenceString("LockedTokens")))
	tx.AddRawArgument(jsoncdc.MustEncode(cadenceCode))
	tx.AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys))

	// Sign and submit the transaction
	err := tx.SignPayload(adminAddress, 0, adminSigner)
	assert.NoError(t, err)
	err = tx.SignEnvelope(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().Signer())
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

/// Creates a new pair of normal and locked accounts
/// with their balances initialized to the provided values
func createLockedAccountPairWithBalances(
	t *testing.T,
	b *emulator.Blockchain,
	accountKeys *test.AccountKeys,
	env templates.Environment,
	adminAmount string,
	lockedBalance, unlockedBalance string,
	adminAccountKey *flow.AccountKey,
	adminAddress flow.Address,
	adminSigner crypto.Signer,
) (flow.Address, flow.Address, crypto.Signer) {

	newUserKey, newUserSigner := accountKeys.NewWithSigner()

	adminPublicKey := bytesToCadenceArray(adminAccountKey.Encode())
	newUserPublicKey := bytesToCadenceArray(newUserKey.Encode())

	var newUserSharedAddress flow.Address
	var newUserAddress flow.Address

	if adminAmount != "0.0" {
		mintTokensForAccount(t, b, adminAddress, adminAmount)
	}

	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateSharedAccountScript(env), adminAddress).
		AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
		AddRawArgument(jsoncdc.MustEncode(newUserPublicKey)).
		AddRawArgument(jsoncdc.MustEncode(newUserPublicKey))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, adminAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
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

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositLockedTokensScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(newUserSharedAddress))
		_ = tx.AddArgument(CadenceUFix64(lockedBalance))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
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

/****************** Staking Collection utilities ************************/

// Struct for each delegator that specifies their node ID and delegator ID
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
	machineAccounts    map[cadence.String]flow.Address
}

type MachineAccountCreatedEvent interface {
	NodeID() cadence.String
	Role() cadence.UInt8
	Address() flow.Address
}
type machineAccountCreatedEvent flow.Event

var _ MachineAccountCreatedEvent = (*machineAccountCreatedEvent)(nil)

// Address returns the address of the newly-created account.
func (evt machineAccountCreatedEvent) NodeID() cadence.String {
	return evt.Value.Fields[0].(cadence.String)
}

// Address returns the address of the newly-created account.
func (evt machineAccountCreatedEvent) Role() cadence.UInt8 {
	return evt.Value.Fields[1].(cadence.UInt8)
}

// Address returns the address of the newly-created account.
func (evt machineAccountCreatedEvent) Address() flow.Address {
	return flow.BytesToAddress(evt.Value.Fields[2].(cadence.Address).Bytes())
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
	FlowStakingCollectionCode := contracts.TESTFlowStakingCollection(emulatorFTAddress,
		emulatorFlowTokenAddress,
		idTableAddress.String(),
		stakingProxyAddress.String(),
		lockedTokensAddress.String(),
		b.ServiceKey().Address.String(),
		env.QuorumCertificateAddress,
		env.DkgAddress,
		env.EpochAddress)

	FlowStakingCollectionByteCode := CadenceString(hex.EncodeToString(FlowStakingCollectionCode))

	// Deploy the staking collection contract
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDeployStakingCollectionScript(), lockedTokensAddress).
		AddRawArgument(jsoncdc.MustEncode(CadenceString("FlowStakingCollection"))).
		AddRawArgument(jsoncdc.MustEncode(FlowStakingCollectionByteCode))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, lockedTokensAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), lockedTokensSigner},
		false,
	)
}

// Deploys the staking contract, staking proxy, locked tokens contract,
// and staking collection contract all in the same function
func deployAllCollectionContracts(t *testing.T,
	b *emulator.Blockchain,
	accountKeys *test.AccountKeys,
	env *templates.Environment,
	adminAddress flow.Address,
	adminSigner crypto.Signer) {

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
	lockedTokensAddress := deployLockedTokensContract(t, b, flow.HexToAddress(env.IDTableAddress), stakingProxyAddress, lockedTokensAccountKey, adminAddress, adminSigner)
	env.StakingProxyAddress = stakingProxyAddress.Hex()
	env.LockedTokensAddress = lockedTokensAddress.Hex()

	// DEPLOY StakingCollection

	deployCollectionContract(t, b, flow.HexToAddress(env.IDTableAddress), stakingProxyAddress, lockedTokensAddress, lockedTokensSigner, env)
}

// Creates a locked account pair with balances in both accounts,
// registers a node and a delegator in the locked account,
// creates a staking collection and stores it in the unlocked account,
// and registers a node and a delegator in the unlocked account.
//
func registerStakingCollectionNodesAndDelegators(
	t *testing.T,
	b *emulator.Blockchain,
	accountKeys *test.AccountKeys,
	env templates.Environment,
	lockedBalance, unlockedBalance string,
	adminAccountKey *flow.AccountKey,
	adminAddress flow.Address,
	adminSigner crypto.Signer,
) (flow.Address, flow.Address, crypto.Signer, string, string) {

	// Create a locked account pair with tokens in both accounts
	newUserAddress, newUserSharedAddress, newUserSigner := createLockedAccountPairWithBalances(
		t, b,
		accountKeys,
		env,
		"1000000000.0",
		lockedBalance, unlockedBalance,
		adminAccountKey, adminAddress, adminSigner)

	// Initialize the two node IDs
	userNodeID1 := "0000000000000000000000000000000000000000000000000000000000000001"
	userNodeID2 := "0000000000000000000000000000000000000000000000000000000000000002"

	_, nodeOneStakingKey, _, nodeOneNetworkingKey := generateKeysForNodeRegistration(t)

	publicKeys := make([]cadence.Value, 1)
	machineAccountKey, _ := accountKeys.NewWithSigner()
	machineAccountKeyString := hex.EncodeToString(machineAccountKey.Encode())
	publicKeys[0] = CadenceString(machineAccountKeyString)
	cadencePublicKeys := cadence.NewArray(publicKeys)

	// Register a node in the locked account
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterLockedNodeScript(env), newUserAddress)
	_ = tx.AddArgument(CadenceString(userNodeID1))
	_ = tx.AddArgument(cadence.NewUInt8(4))
	_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", 1)))
	_ = tx.AddArgument(CadenceString(nodeOneNetworkingKey))
	_ = tx.AddArgument(CadenceString(nodeOneStakingKey))
	_ = tx.AddArgument(CadenceUFix64("320000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, newUserAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), newUserSigner},
		false,
	)

	// Register a delegator in the locked account
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateLockedDelegatorScript(env), newUserAddress)
	_ = tx.AddArgument(CadenceString(userNodeID1))
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

	_, nodeTwoStakingKey, _, nodeTwoNetworkingKey := generateKeysForNodeRegistration(t)

	// Register a node with the staking collection
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterNode(env), newUserAddress)
	_ = tx.AddArgument(CadenceString(userNodeID2))
	_ = tx.AddArgument(cadence.NewUInt8(2))
	_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", 2)))
	_ = tx.AddArgument(CadenceString(nodeTwoNetworkingKey))
	_ = tx.AddArgument(CadenceString(nodeTwoStakingKey))
	_ = tx.AddArgument(CadenceUFix64("500000.0"))
	_ = tx.AddArgument(cadence.NewOptional(cadencePublicKeys))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, newUserAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), newUserSigner},
		false,
	)

	// Register a delegator with the staking collection
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterDelegator(env), newUserAddress)
	_ = tx.AddArgument(CadenceString(userNodeID2))
	_ = tx.AddArgument(CadenceUFix64("500000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, newUserAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), newUserSigner},
		false,
	)

	return newUserAddress, newUserSharedAddress, newUserSigner, userNodeID1, userNodeID2
}

// Queries all the important information from a user's staking collection
// and verifies it against the provided expectedInfo struct
//
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
	for _, resultID := range nodeArray {
		found := false
		for _, expectedID := range expectedInfo.nodes {
			if resultID == CadenceString(expectedID) {
				found = true
			}
		}
		assertEqual(t, found, true)
		i = i + 1
	}

	// check delegator IDs
	result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetDelegatorIDsScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(flow.HexToAddress(expectedInfo.accountAddress)))})
	delegatorArray := result.(cadence.Array).Values
	i = 0
	for _, delegator := range expectedInfo.delegators {
		nodeID := delegatorArray[i].(cadence.Struct).Fields[0]
		delegatorID := delegatorArray[i].(cadence.Struct).Fields[1]
		assertEqual(t, CadenceString(delegator.nodeID), nodeID)
		assertEqual(t, cadence.NewUInt32(delegator.id), delegatorID)
		i = i + 1
	}

	if len(expectedInfo.machineAccounts) != 0 {
		// check machine accounts
		result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetMachineAccountsScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(flow.HexToAddress(expectedInfo.accountAddress)))})
		machineAccountsDictionary := result.(cadence.Dictionary).Pairs
		assertEqual(t, len(expectedInfo.machineAccounts), len(machineAccountsDictionary))
		for _, accountPair := range machineAccountsDictionary {
			nodeID := accountPair.Key.(cadence.String)
			result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetMachineAccountAddressScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(flow.HexToAddress(expectedInfo.accountAddress))), jsoncdc.MustEncode(nodeID)})
			address := result.(cadence.Optional).Value.(cadence.Address)
			assertEqual(t, cadence.NewAddress(expectedInfo.machineAccounts[nodeID]), address)
		}
	}
}

// Queries the machine account address of a recently registered Node
func getMachineAccountFromEvent(
	t *testing.T,
	b *emulator.Blockchain,
	env templates.Environment,
	result *types.TransactionResult,
) flow.Address {

	for _, event := range result.Events {
		if event.Type == fmt.Sprintf("A.%s.FlowStakingCollection.MachineAccountCreated", env.LockedTokensAddress) {
			// needs work
			machineAccountEvent := machineAccountCreatedEvent(event)
			newMachineAccountAddress := machineAccountEvent.Address()
			return newMachineAccountAddress
		}
	}
	return flow.Address{}
}
