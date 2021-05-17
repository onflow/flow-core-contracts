package test

import (
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
