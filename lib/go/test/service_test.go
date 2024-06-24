package test

import (
	"context"
	"fmt"
	"github.com/onflow/flow-emulator/emulator"
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

	b, adapter := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress:  emulatorFTAddress,
		FlowTokenAddress:      emulatorFlowTokenAddress,
		FlowFeesAddress:       emulatorFlowFeesAddress,
		ServiceAccountAddress: b.ServiceKey().Address.Hex(),
		BurnerAddress:         emulatorServiceAccount,
		StorageFeesAddress:    emulatorServiceAccount,
	}

	accountKeys := test.AccountKeyGenerator()

	storageFeesAccountKey, storageFeesSigner := accountKeys.NewWithSigner()

	// deploy the FlowStorageFees contract
	storageFeesCode := contracts.FlowStorageFees(env)
	storageFeesAddress, err := adapter.CreateAccount(context.Background(), []*flow.AccountKey{storageFeesAccountKey}, []sdktemplates.Contract{
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
			[]flow.Address{storageFeesAddress},
			[]crypto.Signer{storageFeesSigner},
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
			[]flow.Address{storageFeesAddress},
			[]crypto.Signer{storageFeesSigner},
			false,
		)
	})

	result = executeScriptAndCheck(t, b, templates.GenerateGetAccountAvailableBalanceFilenameScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(b.ServiceKey().Address))})
	assertEqual(t, CadenceUFix64("999999999.80000000"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetStorageCapacityScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(b.ServiceKey().Address))})
	assertEqual(t, CadenceUFix64("184467440737.09551615"), result)

	t.Run("GenerateGetAccountsCapacityForTransactionStorageCheckScript should work", func(t *testing.T) {
		result = executeScriptAndCheck(t, b, templates.GenerateGetAccountsCapacityForTransactionStorageCheckScript(env), [][]byte{
			jsoncdc.MustEncode(
				cadence.NewArray([]cadence.Value{
					cadence.Address(b.ServiceKey().Address),
					cadence.NewAddress(flow.HexToAddress(env.FlowFeesAddress)),
				})),
			jsoncdc.MustEncode(cadence.Address(b.ServiceKey().Address)),
			jsoncdc.MustEncode(CadenceUFix64("999999999.0")),
		})
		resultArray := result.(cadence.Array)
		assertEqual(t, CadenceUFix64("10000000.00000000"), resultArray.Values[0])
		assertEqual(t, CadenceUFix64("0.00000000"), resultArray.Values[1])
	})

	t.Run("GenerateGetAccountsCapacityForTransactionStorageCheckScript should not underflow", func(t *testing.T) {
		result = executeScriptAndCheck(t, b, templates.GenerateGetAccountsCapacityForTransactionStorageCheckScript(env), [][]byte{
			jsoncdc.MustEncode(
				cadence.NewArray([]cadence.Value{
					cadence.NewAddress(flow.HexToAddress(env.FlowFeesAddress)),
				})),
			jsoncdc.MustEncode(cadence.Address(cadence.NewAddress(flow.HexToAddress(env.FlowFeesAddress)))),
			jsoncdc.MustEncode(CadenceUFix64("999999999.0")),
		})
		resultArray := result.(cadence.Array)
		// The balance of the FlowFeesAddress is 0.0, as evident from the previous test
		// Subtracting max fees of 999999999.0 from 0.0 should result in 0.0,
		// and not underflow.
		assertEqual(t, CadenceUFix64("0.0"), resultArray.Values[0])
	})

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
			[]flow.Address{storageFeesAddress},
			[]crypto.Signer{storageFeesSigner},
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
			[]flow.Address{},
			[]crypto.Signer{},
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
			[]flow.Address{},
			[]crypto.Signer{},
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
			[]flow.Address{},
			[]crypto.Signer{},
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
			[]flow.Address{},
			[]crypto.Signer{},
			false,
		)
	})

	t.Run("Should set and get FlowFees fee parameters", func(t *testing.T) {
		tx := createTxWithTemplateAndAuthorizer(b,
			templates.GenerateSetFeeParametersScript(env),
			b.ServiceKey().Address)

		err := tx.AddArgument(CadenceUFix64("1.0"))
		require.NoError(t, err)
		err = tx.AddArgument(CadenceUFix64("2.0"))
		require.NoError(t, err)
		err = tx.AddArgument(CadenceUFix64("3.0"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{storageFeesAddress},
			[]crypto.Signer{storageFeesSigner},
			false,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetFeeParametersScript(env), [][]byte{})
		fields := cadence.FieldsMappedByName(result.(cadence.Struct))
		assertEqual(t, CadenceUFix64("1.0"), fields["surgeFactor"])
		assertEqual(t, CadenceUFix64("2.0"), fields["inclusionEffortCost"])
		assertEqual(t, CadenceUFix64("3.0"), fields["executionEffortCost"])
	})

	t.Run("Should set and get execution effort weights", func(t *testing.T) {
		tx := createTxWithTemplateAndAuthorizer(b,
			templates.GenerateSetExecutionEffortWeights(env),
			b.ServiceKey().Address)

		keyValuePairs := make([]cadence.KeyValuePair, 3)

		keyValuePairs[0] = cadence.KeyValuePair{
			Key:   cadence.UInt64(1001),
			Value: cadence.UInt64(65536),
		}
		keyValuePairs[1] = cadence.KeyValuePair{
			Key:   cadence.UInt64(1002),
			Value: cadence.UInt64(65536),
		}
		keyValuePairs[2] = cadence.KeyValuePair{
			Key:   cadence.UInt64(1003),
			Value: cadence.UInt64(65536),
		}

		dict := cadence.Dictionary{Pairs: keyValuePairs}

		err := tx.AddArgument(dict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{},
			[]crypto.Signer{},
			false,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetExecutionEffortWeights(env), [][]byte{})
		pairs := result.(cadence.Dictionary).Pairs
		require.Len(t, pairs, 3)
		for _, pair := range pairs {
			for _, expected := range keyValuePairs {
				if pair.Key.(cadence.UInt64) == expected.Key.(cadence.UInt64) {
					require.Equal(t, expected.Value, pair.Value)
				}
			}
		}
	})

	t.Run("Should set and get execution memory weights", func(t *testing.T) {
		tx := createTxWithTemplateAndAuthorizer(b,
			templates.GenerateSetExecutionMemoryWeights(env),
			b.ServiceKey().Address)

		keyValuePairs := make([]cadence.KeyValuePair, 3)

		keyValuePairs[0] = cadence.KeyValuePair{
			Key:   cadence.UInt64(0),
			Value: cadence.UInt64(100),
		}
		keyValuePairs[1] = cadence.KeyValuePair{
			Key:   cadence.UInt64(1),
			Value: cadence.UInt64(101),
		}
		keyValuePairs[2] = cadence.KeyValuePair{
			Key:   cadence.UInt64(2),
			Value: cadence.UInt64(102),
		}

		dict := cadence.Dictionary{Pairs: keyValuePairs}

		err := tx.AddArgument(dict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{},
			[]crypto.Signer{},
			false,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetExecutionMemoryWeights(env), [][]byte{})
		pairs := result.(cadence.Dictionary).Pairs
		require.Len(t, pairs, 3)
		for _, pair := range pairs {
			for _, expected := range keyValuePairs {
				if pair.Key.(cadence.UInt64) == expected.Key.(cadence.UInt64) {
					require.Equal(t, expected.Value, pair.Value)
				}
			}
		}
	})

	t.Run("Should set and get execution memory limit", func(t *testing.T) {
		tx := createTxWithTemplateAndAuthorizer(b,
			templates.GenerateSetExecutionMemoryLimit(env),
			b.ServiceKey().Address)

		newLimit := cadence.UInt64(1234567890)

		err := tx.AddArgument(cadence.UInt64(newLimit))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{},
			[]crypto.Signer{},
			false,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetExecutionMemoryLimit(env), [][]byte{})
		limit := result.(cadence.UInt64)
		require.Equal(t, newLimit, limit)

	})

	t.Run("Should check if payer has sufficient balance to execute tx", func(t *testing.T) {
		// create blockchain with tx fees enabled
		blockchain, adapter := newBlockchain(
			emulator.WithStorageLimitEnabled(true),
			emulator.WithTransactionFeesEnabled(true),
			emulator.WithStorageLimitEnabled(true),
			emulator.WithMinimumStorageReservation(cadence.UFix64(15000)))

		// create SmallBalanceContract contract
		code := []byte(`
			access(all) contract SmallBalanceContract {
    			access(all) var value: Int32

    			init() {
        			self.value = 42
    			}

				access(all) fun SetValue(new_value: Int32) { 
					self.value = new_value
				}
			}
    	`)
		keys := test.AccountKeyGenerator()
		accKey, accSigner := keys.NewWithSigner()
		accAddress, err := adapter.CreateAccount(context.Background(), []*flow.AccountKey{accKey}, []sdktemplates.Contract{
			{
				Name:   "SmallBalanceContract",
				Source: string(code),
			},
		})
		assert.NoError(t, err)
		_, err = blockchain.CommitBlock()
		assert.NoError(t, err)

		// we want to execute some tx so that the payer has less balance than default
		txCode := []byte(fmt.Sprintf(`
			import SmallBalanceContract from 0x%s
			
			transaction(value: Int32) {
			  prepare(signer: auth(Storage) &Account) {}
			
			  execute {
			   if value > SmallBalanceContract.value {
				  SmallBalanceContract.SetValue(new_value: value + 1)
			   } else {
				  SmallBalanceContract.SetValue(new_value: value - 1)
			   }
			  }
			}
		`, accAddress))

		tx := flow.NewTransaction().
			SetScript(txCode).
			SetComputeLimit(9999).
			SetProposalKey(accAddress, 0, 0).
			SetPayer(accAddress).
			AddAuthorizer(accAddress)

		err = tx.AddArgument(cadence.Int32(15))
		require.NoError(t, err)

		err = tx.SignEnvelope(accAddress, 0, accSigner)
		assert.NoError(t, err)

		// this transaction should fail and be reverted, but the fees will still be paid
		// which will push the balance below the minimum account balance
		// calling VerifyPayerBalanceForTxExecution after this will return false.
		txRes := Submit(t, blockchain, tx, true)
		require.True(t, txRes.Reverted())

		// set up args
		cadenceAddress := cadence.NewAddress(accAddress)
		inclusionEffort := cadence.UFix64(100_000_000)
		gasLimit := cadence.UFix64(9999)
		args := [][]byte{jsoncdc.MustEncode(cadenceAddress), jsoncdc.MustEncode(inclusionEffort), jsoncdc.MustEncode(gasLimit)}

		result = executeScriptAndCheck(t, blockchain, templates.GenerateVerifyPayerBalanceForTxExecution(env), args)
		require.NotNil(t, result)

		// we want to get account balance later for comparison
		acc, err := adapter.GetAccount(context.Background(), accAddress)
		require.NoError(t, err)

		// parse VerifyPayerBalanceResult
		resultStruct := result.(cadence.Struct)
		fields := cadence.FieldsMappedByName(resultStruct)

		// actual balance should be less than required
		requiredBalance := uint64(fields["requiredBalance"].(cadence.UFix64))
		require.NotNil(t, requiredBalance)

		actualBalance := acc.Balance
		require.Less(t, actualBalance, requiredBalance)

		// user cannot execute tx as he does not have sufficient balance
		canExecuteTransaction := bool(fields["canExecuteTransaction"].(cadence.Bool))
		require.False(t, canExecuteTransaction)
	})

	// deploy the ServiceAccount contract
	serviceAccountCode := contracts.FlowServiceAccount(
		env,
	)
	_, err = adapter.CreateAccount(context.Background(), nil, []sdktemplates.Contract{
		{
			Name:   "FlowServiceAccount",
			Source: string(serviceAccountCode),
		},
	})
	assert.NoError(t, err)
	_, err = b.CommitBlock()
	assert.NoError(t, err)
}
