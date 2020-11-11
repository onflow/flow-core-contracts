package test

import (
	"fmt"
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	ft_templates "github.com/onflow/flow-ft/lib/go/templates"
	"github.com/onflow/flow-go-sdk"
	sdk "github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

func TestLockedTokensRegistration(t *testing.T) {
	b := newEmulator()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, _ := accountKeys.NewWithSigner()
	IDTableCode := contracts.FlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress)

	publicKeys := make([]cadence.Value, 1)

	publicKeys[0] = bytesToCadenceArray(IDTableAccountKey.Encode())

	cadencePublicKeys := cadence.NewArray(publicKeys)
	cadenceCode := bytesToCadenceArray(IDTableCode)

	// Deploy the IDTableStaking contract
	tx := flow.NewTransaction().
		SetScript(templates.GenerateTransferMinterAndDeployScript(env)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys)).
		AddRawArgument(jsoncdc.MustEncode(cadenceCode))

	_ = tx.AddArgument(CadenceUFix64("1250000.0"))
	_ = tx.AddArgument(CadenceUFix64("0.03"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{b.ServiceKey().Signer()},
		false,
	)

	var idTableAddress sdk.Address

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := b.GetEventsByHeight(i, "flow.AccountCreated")

		for _, event := range results {
			if event.Type == sdk.EventAccountCreated {
				idTableAddress = sdk.Address(event.Value.Fields[0].(cadence.Address))
			}
		}

		i = i + 1
	}

	env.IDTableAddress = idTableAddress.Hex()

	// Deploy the StakingProxy contract
	stakingProxyCode := contracts.FlowStakingProxy()
	stakingProxyAddress, err := b.CreateAccount(nil, stakingProxyCode)
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}

	env.StakingProxyAddress = stakingProxyAddress.Hex()

	_, err = b.CommitBlock()
	assert.NoError(t, err)

	adminAccountKey := accountKeys.New()

	lockedTokensAddress := deployLockedTokensContract(t, b, idTableAddress, stakingProxyAddress)

	env.LockedTokensAddress = lockedTokensAddress.Hex()

	t.Run("Should be able to set up the admin account", func(t *testing.T) {

		script := ft_templates.GenerateMintTokensScript(
			flow.HexToAddress(emulatorFTAddress),
			flow.HexToAddress(emulatorFlowTokenAddress),
			"FlowToken",
		)

		tx = flow.NewTransaction().
			SetScript(script).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(lockedTokensAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)
	})

	// Create new keys for the user account
	joshKey, joshSigner := accountKeys.NewWithSigner()

	adminPublicKey := bytesToCadenceArray(adminAccountKey.Encode())
	joshPublicKey := bytesToCadenceArray(joshKey.Encode())

	var joshSharedAddress sdk.Address
	var joshAddress sdk.Address

	t.Run("Should be able to create new shared accounts", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateSharedAccountScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address).
			AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		createAccountsTxResult, err := b.GetTransactionResult(tx.ID())
		assert.NoError(t, err)
		assert.Equal(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

		for _, event := range createAccountsTxResult.Events {
			if event.Type == fmt.Sprintf("A.%s.LockedTokens.SharedAccountRegistered", lockedTokensAddress.Hex()) {
				// needs work
				sharedAccountCreatedEvent := sharedAccountRegisteredEvent(event)
				joshSharedAddress = sharedAccountCreatedEvent.Address()
				break
			}
		}

		for _, event := range createAccountsTxResult.Events {
			if event.Type == fmt.Sprintf("A.%s.LockedTokens.UnlockedAccountRegistered", lockedTokensAddress.Hex()) {
				// needs work
				unlockedAccountCreatedEvent := unlockedAccountRegisteredEvent(event)
				joshAddress = unlockedAccountCreatedEvent.Address()
				break
			}
		}
	})

	t.Run("Should be able to confirm that the account is registered", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCheckSharedRegistrationScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCheckMainRegistrationScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(joshAddress))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)
	})

	t.Run("Should be able to deposit locked tokens to the shared account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateDepositLockedTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("100.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// check balance of locked account
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)

		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}

		balance := result.Value
		assert.Equal(t, CadenceUFix64("100.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to register josh as a node operator", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRegisterLockedNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("12234"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err := cadence.NewUFix64("50.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Check the node ID
		result, err := b.ExecuteScript(templates.GenerateGetNodeIDScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		id := result.Value
		assert.Equal(t, cadence.NewString(joshID), id.(cadence.String))
	})

	t.Run("Should be able to stake locked tokens", func(t *testing.T) {

		script := templates.GenerateStakeNewLockedTokensScript(env)

		tx := flow.NewTransaction().
			SetScript(script).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("50.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		script = templates.GenerateGetLockedAccountBalanceScript(env)

		// Check balance of locked account
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

	})

}
