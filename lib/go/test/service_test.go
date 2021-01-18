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

func TestContracts(t *testing.T) {
	b := newEmulator()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
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

	result, err := b.ExecuteScript(templates.GenerateGetStorageFeeConversionScript(env), nil)
	require.NoError(t, err)
	if !assert.True(t, result.Succeeded()) {
		t.Log(result.Error.Error())
	}
	conversion := result.Value
	assert.Equal(t, CadenceUFix64("1000000.0"), conversion.(cadence.UFix64))

	result, err = b.ExecuteScript(templates.GenerateGetStorageFeeMinimumScript(env), nil)
	require.NoError(t, err)
	if !assert.True(t, result.Succeeded()) {
		t.Log(result.Error.Error())
	}
	min := result.Value
	assert.Equal(t, CadenceUFix64("0.1"), min.(cadence.UFix64))

	result, err = b.ExecuteScript(templates.GenerateGetStorageCapacityScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(storageFeesAddress))})
	require.NoError(t, err)
	if !assert.True(t, result.Succeeded()) {
		t.Log(result.Error.Error())
	}
	min = result.Value
	assert.Equal(t, CadenceUFix64("0.1"), min.(cadence.UFix64))

	t.Run("Should be able to change the conversion and minimum", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateChangeStorageFeeParametersScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(storageFeesAddress)

		_ = tx.AddArgument(CadenceUFix64("2000000.0"))
		_ = tx.AddArgument(CadenceUFix64("0.2"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, storageFeesAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), storageFeesSigner},
			true,
		)
	})

	result, err = b.ExecuteScript(templates.GenerateGetStorageFeeConversionScript(env), nil)
	require.NoError(t, err)
	if !assert.True(t, result.Succeeded()) {
		t.Log(result.Error.Error())
	}
	conversion = result.Value
	assert.Equal(t, CadenceUFix64("2000000.0"), conversion.(cadence.UFix64))

	result, err = b.ExecuteScript(templates.GenerateGetStorageFeeMinimumScript(env), nil)
	require.NoError(t, err)
	if !assert.True(t, result.Succeeded()) {
		t.Log(result.Error.Error())
	}
	min = result.Value
	assert.Equal(t, CadenceUFix64("0.2"), min.(cadence.UFix64))

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

	// read fields on the ServiceAccount contract
	_ = executeScriptAndCheck(t, b, templates.GenerateInspectFieldScript("transactionFee"))
	_ = executeScriptAndCheck(t, b, templates.GenerateInspectFieldScript("accountCreationFee"))

}
