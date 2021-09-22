package test

import (
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

// This test tests the contracts associated with the service account, such as
// FlowFees, FlowStorageFees, and FlowServiceAccount

func TestContracts(t *testing.T) {

	t.Parallel()

	b := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress:  emulatorFTAddress,
		FlowTokenAddress:      emulatorFlowTokenAddress,
		ServiceAccountAddress: b.ServiceKey().Address.Hex(),
	}

	accountKeys := test.AccountKeyGenerator()

	storageFeesAccountKey, storageFeesSigner := accountKeys.NewWithSigner()

	// deploy the FlowStorageFees contract
	storageFeesCode := contracts.FlowStorageFees(emulatorFTAddress, emulatorFlowTokenAddress)
	storageFeesAddress, err := b.CreateAccount([]*flow.AccountKey{storageFeesAccountKey}, []sdktemplates.Contract{
		{
			Name:   "FlowStorageFees",
			Source: string(storageFeesCode),
		},
	})
	assert.NoError(t, err)
	_, err = b.CommitBlock()
	assert.NoError(t, err)

	env.StorageFeesAddress = storageFeesAddress.String()

	t.Run("Should have initialized fields correctly", func(t *testing.T) {

		result := executeScriptAndCheck(t, b, templates.GenerateGetStorageFeeConversionScript(env), nil)
		assertEqual(t, CadenceUFix64("1.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStorageFeeMinimumScript(env), nil)
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStorageCapacityScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(storageFeesAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)

	})

	t.Run("Should be able to change the conversion and minimum", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b,
			templates.GenerateChangeStorageFeeParametersScript(env),
			storageFeesAddress)

		err := tx.AddArgument(CadenceUFix64("2.0"))
		require.NoError(t, err)
		err = tx.AddArgument(CadenceUFix64("0.2"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, storageFeesAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), storageFeesSigner},
			false,
		)
	})

	result := executeScriptAndCheck(t, b, templates.GenerateGetAccountAvailableBalanceFilenameScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(storageFeesAddress))})
	assertEqual(t, CadenceUFix64("0.0"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetStorageFeeConversionScript(env), nil)
	assertEqual(t, CadenceUFix64("2.0"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetStorageFeeMinimumScript(env), nil)
	assertEqual(t, CadenceUFix64("0.2"), result)

	t.Run("Getting available balance should not overflow", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b,
			templates.GenerateChangeStorageFeeParametersScript(env),
			storageFeesAddress)

		err := tx.AddArgument(CadenceUFix64("10000000.0"))

		require.NoError(t, err)
		err = tx.AddArgument(CadenceUFix64("0.2"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, storageFeesAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), storageFeesSigner},
			false,
		)
	})

	result = executeScriptAndCheck(t, b, templates.GenerateGetAccountAvailableBalanceFilenameScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(b.ServiceKey().Address))})
	assertEqual(t, CadenceUFix64("999999999.80000000"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetStorageCapacityScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(b.ServiceKey().Address))})
	assertEqual(t, CadenceUFix64("184467440737.09551615"), result)

	t.Run("Zero conversion should not result in a divide by zero error", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b,
			templates.GenerateChangeStorageFeeParametersScript(env),
			storageFeesAddress)

		err := tx.AddArgument(CadenceUFix64("0.0"))
		require.NoError(t, err)
		err = tx.AddArgument(CadenceUFix64("0.2"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, storageFeesAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), storageFeesSigner},
			false,
		)
	})

	result = executeScriptAndCheck(t, b, templates.GenerateGetAccountAvailableBalanceFilenameScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(storageFeesAddress))})
	assertEqual(t, CadenceUFix64("0.0"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetStorageFeeConversionScript(env), nil)
	assertEqual(t, CadenceUFix64("0.0"), result)

	t.Run("restricted account creation", func(t *testing.T) {
		accountCreatorAddress := cadence.NewAddress(flow.HexToAddress(emulatorFTAddress))

		// account creation is off
		result := executeScriptAndCheck(t, b, templates.GenerateGetIsAccountCreationRestricted(env), [][]byte{})
		assertEqual(t, cadence.Bool(false), result)

		// service address is an account creator
		result = executeScriptAndCheck(t, b, templates.GenerateGetIsAccountCreator(env), [][]byte{jsoncdc.MustEncode(accountCreatorAddress)})
		assertEqual(t, cadence.Bool(true), result)

		// set restricted account creation
		tx := createTxWithTemplateAndAuthorizer(b,
			templates.GenerateSetIsAccountCreationRestricted(env),
			b.ServiceKey().Address)

		err := tx.AddArgument(cadence.Bool(true))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		// restricted account creation is on
		result = executeScriptAndCheck(t, b, templates.GenerateGetIsAccountCreationRestricted(env), [][]byte{})
		assertEqual(t, cadence.Bool(true), result)

		// service address is not an account creator
		result = executeScriptAndCheck(t, b, templates.GenerateGetIsAccountCreator(env), [][]byte{jsoncdc.MustEncode(accountCreatorAddress)})
		assertEqual(t, cadence.Bool(false), result)

		// set the service address to be an account creator
		tx = createTxWithTemplateAndAuthorizer(b,
			templates.GenerateAddAccountCreator(env),
			b.ServiceKey().Address)

		err = tx.AddArgument(accountCreatorAddress)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		// service address is an account creator
		result = executeScriptAndCheck(t, b, templates.GenerateGetIsAccountCreator(env), [][]byte{jsoncdc.MustEncode(accountCreatorAddress)})
		assertEqual(t, cadence.Bool(true), result)

		// remove the service address as an account creator
		tx = createTxWithTemplateAndAuthorizer(b,
			templates.GenerateRemoveAccountCreator(env),
			b.ServiceKey().Address)

		err = tx.AddArgument(accountCreatorAddress)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		// service address is not an account creator
		result = executeScriptAndCheck(t, b, templates.GenerateGetIsAccountCreator(env), [][]byte{jsoncdc.MustEncode(accountCreatorAddress)})
		assertEqual(t, cadence.Bool(false), result)

		// unset restricted account creation
		tx = createTxWithTemplateAndAuthorizer(b,
			templates.GenerateSetIsAccountCreationRestricted(env),
			b.ServiceKey().Address)

		err = tx.AddArgument(cadence.Bool(false))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)
	})

	// deploy the ServiceAccount contract
	serviceAccountCode := contracts.FlowServiceAccount(
		emulatorFTAddress,
		emulatorFlowTokenAddress,
		"0xe5a8b7f23e8b548f",
		storageFeesAddress.String(),
	)
	_, err = b.CreateAccount(nil, []sdktemplates.Contract{
		{
			Name:   "FlowServiceAccount",
			Source: string(serviceAccountCode),
		},
	})
	assert.NoError(t, err)
	_, err = b.CommitBlock()
	assert.NoError(t, err)

}
