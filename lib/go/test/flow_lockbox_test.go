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

// Shared account Registered event

type SharedAccountRegisteredEvent interface {
	Address() sdk.Address
}

type sharedAccountRegisteredEvent sdk.Event

var _ SharedAccountRegisteredEvent = (*sharedAccountRegisteredEvent)(nil)

// Address returns the address of the newly-created account.
func (evt sharedAccountRegisteredEvent) Address() sdk.Address {
	return sdk.BytesToAddress(evt.Value.Fields[0].(cadence.Address).Bytes())
}

// Unlocked account Registered event

type UnlockedAccountRegisteredEvent interface {
	Address() sdk.Address
}

type unlockedAccountRegisteredEvent sdk.Event

var _ UnlockedAccountRegisteredEvent = (*unlockedAccountRegisteredEvent)(nil)

// Address returns the address of the newly-created account.
func (evt unlockedAccountRegisteredEvent) Address() sdk.Address {
	return sdk.BytesToAddress(evt.Value.Fields[0].(cadence.Address).Bytes())
}

func TestLockedTokensStaker(t *testing.T) {
	b := newEmulator()

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, _ := accountKeys.NewWithSigner()
	IDTableCode := contracts.TESTFlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress)

	publicKeys := make([]cadence.Value, 1)

	publicKeys[0] = bytesToCadenceArray(IDTableAccountKey.Encode())

	cadencePublicKeys := cadence.NewArray(publicKeys)
	cadenceCode := bytesToCadenceArray(IDTableCode)

	// Deploy the IDTableStaking contract
	tx := flow.NewTransaction().
		SetScript(templates.GenerateTransferMinterAndDeployScript(emulatorFTAddress, emulatorFlowTokenAddress)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys)).
		AddRawArgument(jsoncdc.MustEncode(cadenceCode))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{b.ServiceKey().Signer()},
		false,
	)

	var IDTableAddr sdk.Address

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := b.GetEventsByHeight(i, "flow.AccountCreated")

		for _, event := range results {
			if event.Type == sdk.EventAccountCreated {
				IDTableAddr = sdk.Address(event.Value.Fields[0].(cadence.Address))
			}
		}

		i = i + 1
	}

	// Deploy the StakingProxy contract
	stakingProxyCode := contracts.FlowStakingProxy()
	proxyAddr, err := b.CreateAccount(nil, stakingProxyCode)
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}

	_, err = b.CommitBlock()
	assert.NoError(t, err)

	lockedTokensCode := contracts.FlowLockedTokens(
		emulatorFTAddress,
		emulatorFlowTokenAddress,
		IDTableAddr.Hex(),
		proxyAddr.Hex(),
	)

	lockedTokensAddr, err := b.CreateAccount(nil, lockedTokensCode)
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}

	_, err = b.CommitBlock()
	assert.NoError(t, err)

	// Create new admin account
	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

	t.Run("Should be able to set up the admin account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateAdminCollectionScript(lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(adminAddress))
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
			SetScript(templates.GenerateCreateSharedAccountScript(emulatorFTAddress, emulatorFlowTokenAddress, lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress).
			AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
			false,
		)

		createAccountsTxResult, err := b.GetTransactionResult(tx.ID())
		assert.NoError(t, err)
		assert.Equal(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

		for _, event := range createAccountsTxResult.Events {
			if event.Type == fmt.Sprintf("A.%s.LockedTokens.SharedAccountRegistered", lockedTokensAddr.Hex()) {
				// needs work
				sharedAccountCreatedEvent := sharedAccountRegisteredEvent(event)
				joshSharedAddress = sharedAccountCreatedEvent.Address()
				break
			}
		}

		for _, event := range createAccountsTxResult.Events {
			if event.Type == fmt.Sprintf("A.%s.LockedTokens.UnlockedAccountRegistered", lockedTokensAddr.Hex()) {
				// needs work
				unlockedAccountCreatedEvent := unlockedAccountRegisteredEvent(event)
				joshAddress = unlockedAccountCreatedEvent.Address()
				break
			}
		}
	})

	t.Run("Should be able to deposit locked tokens to the shared account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateDepositLockedTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress)

		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(lockedTokensAddr.String())

		// check balance of locked account
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)

		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}

		balance := result.Value
		assert.Equal(t, CadenceUFix64("1000000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should not be able to withdraw any locked tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateWithdrawTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("10000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(lockedTokensAddr.String())

		// make sure balance of locked account hasn't changed
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("1000000.0"), balance.(cadence.UFix64))

		// make sure balance of unlocked account hasn't changed
		result, err = b.ExecuteScript(ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to unlock tokens from the shared account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateIncreaseUnlockLimitScript(lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress)

		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
			false,
		)

		// Check unlock limit of the shared account
		result, err := b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("10000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to withdraw free tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateWithdrawTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("10000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(lockedTokensAddr.String())

		// Check balance of locked account
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("990000.0"), balance.(cadence.UFix64))

		// check balance of unlocked account
		result, err = b.ExecuteScript(ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("10000.0"), balance.(cadence.UFix64))

		// withdraw limit should have decreased to zero
		result, err = b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to deposit tokens from the unlocked account and increase withdraw limit", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateDepositTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("5000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(lockedTokensAddr.String())

		// Check balance of locked account
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("995000.0"), balance.(cadence.UFix64))

		// check balance of unlocked account
		result, err = b.ExecuteScript(ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("5000.0"), balance.(cadence.UFix64))

		// make sure unlock limit has increased by 5000
		result, err = b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("5000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to register josh as a node operator", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateLockedNodeScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("12234"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err := cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// unlock limit should not have changed
		result, err := b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("5000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should not be able to register a second time", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateLockedNodeScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("12234"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err := cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)
	})

	t.Run("Should not be able to register as a delegator after registering as a node operator", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateLockedDelegatorScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))
		tokenAmount, err := cadence.NewUFix64("20000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)
	})

	t.Run("Should be able to stake locked tokens", func(t *testing.T) {

		script := templates.GenerateStakeNewLockedTokensScript(
			emulatorFTAddress,
			emulatorFlowTokenAddress,
			lockedTokensAddr.String(),
			proxyAddr.String(),
		)

		tx := flow.NewTransaction().
			SetScript(script).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("2000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		script = templates.GenerateGetLockedAccountBalanceScript(lockedTokensAddr.String())

		// Check balance of locked account
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("743000.0"), balance.(cadence.UFix64))

		// unlock limit should not have changed
		result, err = b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("5000.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to stake unstaked tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStakeLockedUnstakedTokensScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("1000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// unlock limit should not have changed
		result, err := b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("5000.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to stake rewarded tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStakeLockedRewardedTokensScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("1000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Make sure that the unlock limit has increased by 1000.0
		result, err := b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("6000.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to request unstaking", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateUnstakeLockedTokensScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("500.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

	})

	t.Run("Should be able to request unstaking all tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateUnstakeAllLockedTokensScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)
	})

	t.Run("Should be able to withdraw unstaked tokens which are deposited to the locked vault (still locked)", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateWithdrawLockedUnstakedTokensScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("500.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(lockedTokensAddr.String())

		// locked tokens balance should increase by 500
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("743500.0"), balance.(cadence.UFix64))

		// make sure the unlock limit hasn't changed
		result, err = b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("6000.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to withdraw rewards tokens which are deposited to the locked vault (increase limit)", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateWithdrawLockedRewardedTokensScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("500.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(lockedTokensAddr.String())

		// locked tokens balance should increase by 500
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("744000.0"), balance.(cadence.UFix64))

		// make sure the unlock limit has increased by 500.0
		result, err = b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("6500.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to stake tokens that come from the locked vault first and then the unlocked vault", func(t *testing.T) {

		script := templates.GenerateStakeNewLockedTokensScript(
			emulatorFTAddress,
			emulatorFlowTokenAddress,
			lockedTokensAddr.String(),
			proxyAddr.String(),
		)

		tx := flow.NewTransaction().
			SetScript(script).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("746000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Check balance of locked account
		result, err := b.ExecuteScript(ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshSharedAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("3000.0"), balance.(cadence.UFix64))

		// unlock limit should not have changed
		result, err = b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("8500.0"), balance.(cadence.UFix64))

	})

}

func TestLockedTokensDelegator(t *testing.T) {
	b := newEmulator()

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, _ := accountKeys.NewWithSigner()
	IDTableCode := contracts.TESTFlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress)

	publicKeys := make([]cadence.Value, 1)

	publicKeys[0] = bytesToCadenceArray(IDTableAccountKey.Encode())

	cadencePublicKeys := cadence.NewArray(publicKeys)
	cadenceCode := bytesToCadenceArray(IDTableCode)

	// Deploy the IDTableStaking contract
	tx := flow.NewTransaction().
		SetScript(templates.GenerateTransferMinterAndDeployScript(emulatorFTAddress, emulatorFlowTokenAddress)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys)).
		AddRawArgument(jsoncdc.MustEncode(cadenceCode))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{b.ServiceKey().Signer()},
		false,
	)

	var IDTableAddr sdk.Address

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := b.GetEventsByHeight(i, "flow.AccountCreated")

		for _, event := range results {
			if event.Type == sdk.EventAccountCreated {
				IDTableAddr = sdk.Address(event.Value.Fields[0].(cadence.Address))
			}
		}

		i = i + 1
	}

	// Deploy the StakingProxy contract
	stakingProxyCode := contracts.FlowStakingProxy()
	proxyAddr, err := b.CreateAccount(nil, stakingProxyCode)
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}

	_, err = b.CommitBlock()
	assert.NoError(t, err)

	lockedTokensCode := contracts.FlowLockedTokens(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String(), proxyAddr.String())

	lockedTokensAddr, err := b.CreateAccount(nil, []byte(lockedTokensCode))
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}

	_, err = b.CommitBlock()
	assert.NoError(t, err)

	// Create new admin account
	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

	t.Run("Should be able to set up the admin account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateAdminCollectionScript(lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(adminAddress))
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
			SetScript(templates.GenerateCreateSharedAccountScript(emulatorFTAddress, emulatorFlowTokenAddress, lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress).
			AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
			false,
		)

		createAccountsTxResult, err := b.GetTransactionResult(tx.ID())
		assert.NoError(t, err)
		assert.Equal(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

		for _, event := range createAccountsTxResult.Events {
			if event.Type == fmt.Sprintf("A.%s.LockedTokens.SharedAccountRegistered", lockedTokensAddr.Hex()) {
				// needs work
				sharedAccountCreatedEvent := sharedAccountRegisteredEvent(event)
				joshSharedAddress = sharedAccountCreatedEvent.Address()
				break
			}
		}

		for _, event := range createAccountsTxResult.Events {
			if event.Type == fmt.Sprintf("A.%s.LockedTokens.UnlockedAccountRegistered", lockedTokensAddr.Hex()) {
				// needs work
				unlockedAccountCreatedEvent := unlockedAccountRegisteredEvent(event)
				joshAddress = unlockedAccountCreatedEvent.Address()
				break
			}
		}
	})

	t.Run("Should be able to deposit locked tokens to the shared account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateDepositLockedTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress)

		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
			false,
		)

		// check balance of locked account
	})

	t.Run("Should be able to register josh as a delegator", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateLockedDelegatorScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))
		tokenAmount, err := cadence.NewUFix64("50000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)
	})

	t.Run("Should not be able to register a second time", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateLockedDelegatorScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))
		tokenAmount, err := cadence.NewUFix64("50000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)
	})

	t.Run("Should not be able to register as a node operator after registering as a delegator", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateLockedNodeScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("12234"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err := cadence.NewUFix64("20000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)
	})

	t.Run("Should be able to delegate locked tokens", func(t *testing.T) {

		script := templates.GenerateDelegateNewLockedTokensScript(
			emulatorFTAddress,
			emulatorFlowTokenAddress,
			lockedTokensAddr.String(),
			proxyAddr.String(),
		)

		tx := flow.NewTransaction().
			SetScript(script).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("2000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Check balance of locked account
		result, err := b.ExecuteScript(ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshSharedAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("948000.0"), balance.(cadence.UFix64))

		// make sure the unlock limit is zero
		result, err = b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to delegate unstaked tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateDelegateLockedUnstakedTokensScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("1000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(lockedTokensAddr.String())

		// Check balance of locked account
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("948000.0"), balance.(cadence.UFix64))

		// make sure the unlock limit is zero
		result, err = b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to delegate rewarded tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateDelegateLockedRewardedTokensScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("1000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(lockedTokensAddr.String())

		// Check balance of locked account. should not have changed
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("948000.0"), balance.(cadence.UFix64))

		// Make sure that the unlock limit has increased by 1000.0
		result, err = b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("1000.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to request unstaking", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateUnDelegateLockedTokensScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("500.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

	})

	t.Run("Should be able to withdraw unstaked tokens which are deposited to the locked vault (still locked)", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateWithdrawDelegatorLockedUnstakedTokensScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("500.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(lockedTokensAddr.String())

		// Check balance of locked account. should have increased by 500
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("948500.0"), balance.(cadence.UFix64))

		// unlocked account balance should not increase
		result, err = b.ExecuteScript(ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		// make sure the unlock limit hasn't changed
		result, err = b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("1000.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to withdraw rewards tokens which are deposited to the locked vault (increase limit)", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateWithdrawDelegatorLockedRewardedTokensScript(lockedTokensAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("500.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(lockedTokensAddr.String())

		// Check balance of locked account. should have increased by 500
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("949000.0"), balance.(cadence.UFix64))

		// unlocked account balance should not have changed
		result, err = b.ExecuteScript(ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		// make sure the unlock limit has increased by 500.0
		result, err = b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("1500.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to withdraw free tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateWithdrawTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("1500.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// make sure the unlock limit has increased by 500.0
		result, err := b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to delegate tokens that come from the locked vault first and then the unlocked vault", func(t *testing.T) {

		script := templates.GenerateDelegateNewLockedTokensScript(
			emulatorFTAddress,
			emulatorFlowTokenAddress,
			lockedTokensAddr.String(),
			proxyAddr.String(),
		)

		tx := flow.NewTransaction().
			SetScript(script).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("949000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Check balance of locked account
		result, err := b.ExecuteScript(ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshSharedAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		// unlock limit should not have changed
		result, err = b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("1500.0"), balance.(cadence.UFix64))

	})

}

func TestCustodyProviderAccountCreation(t *testing.T) {
	b := newEmulator()

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, _ := accountKeys.NewWithSigner()
	IDTableCode := contracts.TESTFlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress)

	publicKeys := make([]cadence.Value, 1)

	publicKeys[0] = bytesToCadenceArray(IDTableAccountKey.Encode())

	cadencePublicKeys := cadence.NewArray(publicKeys)
	cadenceCode := bytesToCadenceArray(IDTableCode)

	// Deploy the IDTableStaking contract
	tx := flow.NewTransaction().
		SetScript(templates.GenerateTransferMinterAndDeployScript(emulatorFTAddress, emulatorFlowTokenAddress)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys)).
		AddRawArgument(jsoncdc.MustEncode(cadenceCode))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{b.ServiceKey().Signer()},
		false,
	)

	var IDTableAddr sdk.Address

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := b.GetEventsByHeight(i, "flow.AccountCreated")

		for _, event := range results {
			if event.Type == sdk.EventAccountCreated {
				IDTableAddr = sdk.Address(event.Value.Fields[0].(cadence.Address))
			}
		}

		i = i + 1
	}

	// Deploy the StakingProxy contract
	stakingProxyCode := contracts.FlowStakingProxy()
	proxyAddr, err := b.CreateAccount(nil, stakingProxyCode)
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}

	_, err = b.CommitBlock()
	assert.NoError(t, err)

	lockedTokensCode := contracts.FlowLockedTokens(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String(), proxyAddr.String())

	lockedTokensAddr, err := b.CreateAccount(nil, []byte(lockedTokensCode))
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}

	_, err = b.CommitBlock()
	assert.NoError(t, err)

	// Create new admin account
	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

	t.Run("Should be able to set up the admin account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateAdminCollectionScript(lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(adminAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)
	})

	// Create new custody provider account
	custodyAccountKey, custodySigner := accountKeys.NewWithSigner()
	custodyAddress, _ := b.CreateAccount([]*flow.AccountKey{custodyAccountKey}, nil)

	t.Run("Should be able to set up the custody provider account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateSetupCustodyAccountScript(lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(custodyAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, custodyAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), custodySigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(custodyAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)
	})

	t.Run("Should be able to deposit an account creator resource into the custody account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateDepositAccountCreatorScript(lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress)

		_ = tx.AddArgument(cadence.NewAddress(custodyAddress))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
			false,
		)
	})

	// Create new keys for the user account
	joshKey, _ := accountKeys.NewWithSigner()

	adminPublicKey := bytesToCadenceArray(adminAccountKey.Encode())
	joshPublicKey := bytesToCadenceArray(joshKey.Encode())

	var joshSharedAddress sdk.Address
	var joshAddress sdk.Address

	t.Run("Should be able to create new shared accounts as the custody provider and give the admin the admin capability", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCustodyCreateAccountsScript(emulatorFTAddress, emulatorFlowTokenAddress, lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(custodyAddress).
			AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, custodyAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), custodySigner},
			false,
		)

		createAccountsTxResult, err := b.GetTransactionResult(tx.ID())
		assert.NoError(t, err)
		assert.Equal(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

		for _, event := range createAccountsTxResult.Events {
			if event.Type == fmt.Sprintf("A.%s.LockedTokens.SharedAccountRegistered", lockedTokensAddr.Hex()) {
				// needs work
				sharedAccountCreatedEvent := sharedAccountRegisteredEvent(event)
				joshSharedAddress = sharedAccountCreatedEvent.Address()
				break
			}
		}

		for _, event := range createAccountsTxResult.Events {
			if event.Type == fmt.Sprintf("A.%s.LockedTokens.UnlockedAccountRegistered", lockedTokensAddr.Hex()) {
				// needs work
				unlockedAccountCreatedEvent := unlockedAccountRegisteredEvent(event)
				joshAddress = unlockedAccountCreatedEvent.Address()
				break
			}
		}
	})

	t.Run("Unlocked account should be connected to locked account", func(t *testing.T) {
		script := templates.GenerateGetLockedAccountAddressScript(lockedTokensAddr.String())

		// Check that locked account is connected to unlocked account
		result, err := b.ExecuteScript(script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		require.NoError(t, result.Error)

		lockedAddress := result.Value.(cadence.Address)

		assert.Equal(t, cadence.Address(joshSharedAddress), lockedAddress)
	})

	// Create new keys for a new user account
	maxKey, maxSigner := accountKeys.NewWithSigner()
	maxAddress, _ := b.CreateAccount([]*flow.AccountKey{maxKey}, nil)

	maxPublicKey := bytesToCadenceArray(maxKey.Encode())

	var maxSharedAddress sdk.Address

	t.Run("Should be able to create a new shared account for an existing account as the custody provider and give the admin the admin capability", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCustodyCreateOnlySharedAccountScript(emulatorFTAddress, emulatorFlowTokenAddress, lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(custodyAddress).
			AddAuthorizer(maxAddress).
			AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(maxPublicKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, custodyAddress, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), custodySigner, maxSigner},
			false,
		)

		createAccountsTxResult, err := b.GetTransactionResult(tx.ID())
		assert.NoError(t, err)
		assert.Equal(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

		for _, event := range createAccountsTxResult.Events {
			if event.Type == fmt.Sprintf("A.%s.LockedTokens.SharedAccountRegistered", lockedTokensAddr.Hex()) {
				// needs work
				sharedAccountCreatedEvent := sharedAccountRegisteredEvent(event)
				maxSharedAddress = sharedAccountCreatedEvent.Address()
				break
			}
		}

		// Check that that admin received the unlock limit capability
	})

	t.Run("Should be able to increase the unlock limit for the new accounts", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateIncreaseUnlockLimitScript(lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress)

		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
			false,
		)

		// Check unlock limit of the shared account
		result, err := b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		require.NoError(t, result.Error)

		balance := result.Value
		assert.Equal(t, CadenceUFix64("10000.0"), balance.(cadence.UFix64))

		tx = flow.NewTransaction().
			SetScript(templates.GenerateIncreaseUnlockLimitScript(lockedTokensAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminAddress)

		_ = tx.AddArgument(cadence.NewAddress(maxSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminSigner},
			false,
		)

		// Check unlock limit of the shared account
		result, err = b.ExecuteScript(templates.GenerateGetUnlockLimitScript(lockedTokensAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.Address(maxAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("10000.0"), balance.(cadence.UFix64))
	})

}
