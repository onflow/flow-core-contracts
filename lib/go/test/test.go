package test

import (
	"fmt"
	"io/ioutil"
	"math/rand"
	"testing"

	"github.com/onflow/flow-emulator/types"

	"github.com/onflow/cadence"
	emulator "github.com/onflow/flow-emulator"
	ft_templates "github.com/onflow/flow-ft/lib/go/templates"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	flow_crypto "github.com/onflow/flow-go/crypto"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

/***********************************************
*
*    flow-core-contracts/lib/go/test/test.go
*
*    Provides common testing utilities for automated testing using the Flow emulator
*    such as setting up the emulator, submitting transactions and scripts,
*    constructing cadence values, creating accounts, and minting tokens
*
*    To use, import the `onflow/flow-core-contracts/lib/go/test` package
*    and call any of these functions, such as:
*
*    test.newTestSetup(t)
*
************************************************/

const (
	emulatorFTAddress        = "ee82856bf20e2aa6"
	emulatorFlowTokenAddress = "0ae53cb6e3f42a79"
	emulatorFlowFeesAddress  = "e5a8b7f23e8b548f"
	emulatorStorageFees      = "f8d6e0586b0a20c7"
)

// Sets up testing and emulator objects and initialize the emulator default addresses
func newTestSetup(t *testing.T) (*emulator.Blockchain, *test.AccountKeys, templates.Environment) {
	// Set for parallel processing
	t.Parallel()

	// Create a new emulator instance
	b := newBlockchain()

	// Create a new account key generator object to generate keys
	// for test accounts
	accountKeys := test.AccountKeyGenerator()

	// Setup the env variable that stores import addresses for various contracts
	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	return b, accountKeys, env
}

// newBlockchain returns an emulator blockchain for testing.
func newBlockchain(opts ...emulator.Option) *emulator.Blockchain {
	b, err := emulator.NewBlockchain(
		append(
			[]emulator.Option{
				// No storage limit
				emulator.WithStorageLimitEnabled(false),
			},
			opts...,
		)...,
	)
	if err != nil {
		panic(err)
	}
	return b
}

// Create a new, empty account for testing
// and return the address, public keys, and signer objects
func newAccountWithAddress(b *emulator.Blockchain, accountKeys *test.AccountKeys) (flow.Address, *flow.AccountKey, crypto.Signer) {
	newAccountKey, newSigner := accountKeys.NewWithSigner()
	newAddress, _ := b.CreateAccount([]*flow.AccountKey{newAccountKey}, nil)

	return newAddress, newAccountKey, newSigner
}

// Create a basic transaction template with the provided transaction script
// Sets the service account as the proposer and payer
// Uses the max gas limit
// authorizer address is the authorizer for the transaction (transaction has access to their AuthAccount object)
// Whoever authorizes here also needs to sign the envelope and payload when submitting the transaction
// returns the tx object so arguments can be added to it and it can be signed
func createTxWithTemplateAndAuthorizer(
	b *emulator.Blockchain,
	script []byte,
	authorizerAddress flow.Address,
) *flow.Transaction {

	tx := flow.NewTransaction().
		SetScript(script).
		SetGasLimit(9999).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(authorizerAddress)

	return tx
}

// signAndSubmit signs a transaction with an array of signers and adds their signatures to the transaction
// before submitting it to the emulator.
//
// If the private keys do not match up with the addresses, the transaction will not succeed.
//
// The shouldRevert parameter indicates whether the transaction should fail or not.
//
// This function asserts the correct result and commits the block if it passed.
func signAndSubmit(
	t *testing.T,
	b *emulator.Blockchain,
	tx *flow.Transaction,
	signerAddresses []flow.Address,
	signers []crypto.Signer,
	shouldRevert bool,
) *types.TransactionResult {
	// sign transaction with each signer
	for i := len(signerAddresses) - 1; i >= 0; i-- {
		signerAddress := signerAddresses[i]
		signer := signers[i]

		err := tx.SignPayload(signerAddress, 0, signer)
		assert.NoError(t, err)
	}

	serviceSigner, _ := b.ServiceKey().Signer()

	err := tx.SignEnvelope(b.ServiceKey().Address, 0, serviceSigner)
	assert.NoError(t, err)

	return Submit(t, b, tx, shouldRevert)
}

// Submit submits a transaction and checks if it fails or not, based on shouldRevert specification
func Submit(
	t *testing.T,
	b *emulator.Blockchain,
	tx *flow.Transaction,
	shouldRevert bool,
) *types.TransactionResult {
	// submit the signed transaction
	err := b.AddTransaction(*tx)
	require.NoError(t, err)

	// use the emulator to execute it
	result, err := b.ExecuteNextTransaction()
	require.NoError(t, err)

	// Check the status
	if shouldRevert {
		assert.True(t, result.Reverted())
	} else {
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
	}

	_, err = b.CommitBlock()
	assert.NoError(t, err)

	return result
}

// executeScriptAndCheck executes a script and checks to make sure that it succeeded.
func executeScriptAndCheck(t *testing.T, b *emulator.Blockchain, script []byte, arguments [][]byte) cadence.Value {
	result, err := b.ExecuteScript(script, arguments)
	require.NoError(t, err)
	if !assert.True(t, result.Succeeded()) {
		t.Log(result.Error.Error())
	}

	return result.Value
}

// Reads a file from the specified path
func readFile(path string) []byte {
	contents, err := ioutil.ReadFile(path)
	if err != nil {
		panic(err)
	}
	return contents
}

// CadenceUFix64 returns a UFix64 value from a string representation
func CadenceUFix64(value string) cadence.Value {
	newValue, err := cadence.NewUFix64(value)

	if err != nil {
		panic(err)
	}

	return newValue
}

// CadenceUInt64 returns a UInt64 value from a uint64
func CadenceUInt64(value uint64) cadence.Value {
	return cadence.NewUInt64(value)
}

// CadenceUInt8 returns a UInt8 value from a uint8
func CadenceUInt8(value uint8) cadence.Value {
	return cadence.NewUInt8(value)
}

// CadenceString returns a string value from a string representation
func CadenceString(value string) cadence.Value {
	newValue, err := cadence.NewString(value)

	if err != nil {
		panic(err)
	}

	return newValue
}

// Converts a byte array to a Cadence array of UInt8
func bytesToCadenceArray(b []byte) cadence.Array {
	values := make([]cadence.Value, len(b))

	for i, v := range b {
		values[i] = cadence.NewUInt8(v)
	}

	return cadence.NewArray(values)
}

// assertEqual asserts that two objects are equal.
//
//	assertEqual(t, 123, 123)
//
// Pointer variable equality is determined based on the equality of the
// referenced values (as opposed to the memory addresses). Function equality
// cannot be determined and will always fail.
func assertEqual(t *testing.T, expected, actual interface{}) bool {

	if assert.ObjectsAreEqual(expected, actual) {
		return true
	}

	message := fmt.Sprintf(
		"Not equal: \nexpected: %s\nactual  : %s",
		expected,
		actual,
	)

	return assert.Fail(t, message)
}

// Mints the specified amount of FLOW tokens for the specified account address
// Using the mint tokens template from the onflow/flow-ft repo
// signed by the service account
func mintTokensForAccount(t *testing.T, b *emulator.Blockchain, recipient flow.Address, amount string) {

	// Create a new mint FLOW transaction template authorized by the service account
	tx := createTxWithTemplateAndAuthorizer(b,
		ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"),
		b.ServiceKey().Address)

	// Add the recipient and amount as arguments
	_ = tx.AddArgument(cadence.NewAddress(recipient))
	_ = tx.AddArgument(CadenceUFix64(amount))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{},
		[]crypto.Signer{},
		false,
	)
}

// Creates multiple accounts and mints 1B tokens for each one
// Returns the addresses, keys, and signers for each account in matching arrays
func registerAndMintManyAccounts(
	t *testing.T,
	b *emulator.Blockchain,
	accountKeys *test.AccountKeys,
	numAccounts int) ([]flow.Address, []*flow.AccountKey, []crypto.Signer) {

	// make new addresses, keys, and signers
	var userAddresses = make([]flow.Address, numAccounts)
	var userPublicKeys = make([]*flow.AccountKey, numAccounts)
	var userSigners = make([]crypto.Signer, numAccounts)

	// Create each new account and mint 1B tokens for it
	for i := 0; i < numAccounts; i++ {
		userAddresses[i], userPublicKeys[i], userSigners[i] = newAccountWithAddress(b, accountKeys)
		mintTokensForAccount(t, b, userAddresses[i], "1000000000.0")
	}

	return userAddresses, userPublicKeys, userSigners
}

// Generates a new private/public key pair
func generateKeys(t *testing.T, algorithmName flow_crypto.SigningAlgorithm) (crypto.PrivateKey, crypto.PublicKey) {
	seedMinLength := 48
	seed := make([]byte, seedMinLength)
	n, err := rand.Read(seed)
	require.Equal(t, n, seedMinLength)
	require.NoError(t, err)
	sk, err := flow_crypto.GeneratePrivateKey(algorithmName, seed)
	require.NoError(t, err)

	publicKey := sk.PublicKey()

	return sk, publicKey
}
