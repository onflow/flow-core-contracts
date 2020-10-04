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

// Shared account created event

type SharedAccountCreatedEvent interface {
	Address() cadence.Address
}

type sharedAccountCreatedEvent cadence.Event

var _ SharedAccountCreatedEvent = (*sharedAccountCreatedEvent)(nil)

// Address returns the address of the newly-created account.
func (evt sharedAccountCreatedEvent) Address() cadence.Address {
	return cadence.BytesToAddress(evt.Fields[0].(cadence.Address).Bytes())
}

func DecodeSharedAccountCreatedEvent(b []byte) (SharedAccountCreatedEvent, error) {
	value, err := jsoncdc.Decode(b)
	if err != nil {
		return nil, err
	}
	return sharedAccountCreatedEvent(value.(cadence.Event)), nil
}

// Unlocked account created event

type UnlockedAccountCreatedEvent interface {
	Address() cadence.Address
}

type unlockedAccountCreatedEvent cadence.Event

var _ UnlockedAccountCreatedEvent = (*unlockedAccountCreatedEvent)(nil)

// Address returns the address of the newly-created account.
func (evt unlockedAccountCreatedEvent) Address() cadence.Address {
	return cadence.BytesToAddress(evt.Fields[0].(cadence.Address).Bytes())
}

func DecodeUnlockedAccountCreatedEvent(b []byte) (UnlockedAccountCreatedEvent, error) {
	value, err := jsoncdc.Decode(b)
	if err != nil {
		return nil, err
	}
	return unlockedAccountCreatedEvent(value.(cadence.Event)), nil
}

func TestLockboxStaker(t *testing.T) {
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
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

	lockboxCode := contracts.FlowLockbox(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String(), proxyAddr.String())

	lockboxAddr, err := b.CreateAccount(nil, []byte(lockboxCode))
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
			SetScript(templates.GenerateCreateAdminCollectionScript(lockboxAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetScript(templates.GenerateCreateSharedAccountScript(emulatorFTAddress, emulatorFlowTokenAddress, lockboxAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			if event.Type == fmt.Sprintf("A.%s.Lockbox.SharedAccountCreated", lockboxAddr.Hex()) {
				// needs work
				sharedAccountCreatedEvent := sharedAccountCreatedEvent(event)
				joshSharedAddress = sharedAccountCreatedEvent.Address()
				break
			}

			assert.Fail(t, "missing shared account created event")
		}

		for _, event := range createAccountsTxResult.Events {
			if event.Type == fmt.Sprintf("A.%s.Lockbox.UnlockedAccountCreated", lockboxAddr.Hex()) {
				// needs work
				sharedAccountCreatedEvent := sharedAccountCreatedEvent(event)
				joshSharedAddress = sharedAccountCreatedEvent.Address()
				break
			}

			assert.Fail(t, "missing shared account created event")
		}
	})

	t.Run("Should be able to deposit locked tokens to the shared account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateDepositLockedTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, lockboxAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

	t.Run("Should not be able to withdraw any locked tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateWithdrawTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, lockboxAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		// make sure balance of locked account hasn't changed

		// make sure balance of unlocked account hasn't changed
	})

	t.Run("Should be able to unlock tokens from the shared account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateIncreaseUnlockLimitScript(lockboxAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
	})

	t.Run("Should be able to withdraw free tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateWithdrawTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, lockboxAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		// Check balance of locked account

		// check balance of unlocked account
	})

	t.Run("Should be able to deposit tokens from the unlocked account and increase withdraw limit", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateDepositTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, lockboxAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		// Check balance of locked account

		// check balance of unlocked account

		// make sure unlock limit has increased by 5000
	})

	t.Run("Should be able to register josh as a node operator", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateLockedNodeScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
	})

	t.Run("Should not be able to register a second time", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateLockedNodeScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
	})

	t.Run("Should not be able to register as a delegator after registering as a node operator", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateLockedDelegatorScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			false,
		)
	})

	t.Run("Should be able to stake locked tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStakeNewLockedTokensScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

	})

	t.Run("Should be able to stake unlocked (staking) tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStakeLockedUnlockedTokensScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

	})

	t.Run("Should be able to stake rewarded tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStakeLockedRewardedTokensScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

	})

	t.Run("Should be able to request unstaking", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateUnstakeLockedTokensScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetScript(templates.GenerateUnstakeAllLockedTokensScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)
	})

	t.Run("Should be able to withdraw unlocked (staking) tokens which are deposited to the locked vault (still locked)", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateWithdrawLockedUnlockedTokensScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		// make sure the unlock limit hasn't changed

	})

	t.Run("Should be able to withdraw rewards tokens which are deposited to the locked vault (increase limit)", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateWithdrawLockedRewardedTokensScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		// make sure the unlock limit has increased by 500.0
	})

}

func TestLockboxDelegator(t *testing.T) {
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
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

	lockboxCode := contracts.FlowLockbox(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String(), proxyAddr.String())

	lockboxAddr, err := b.CreateAccount(nil, []byte(lockboxCode))
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
			SetScript(templates.GenerateCreateAdminCollectionScript(lockboxAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetScript(templates.GenerateCreateSharedAccountScript(emulatorFTAddress, emulatorFlowTokenAddress, lockboxAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			if event.Type == lockboxAddr.String()+"Lockbox.SharedAccountCreated" {
				// needs work
				accountCreatedEvent := flow.AccountCreatedEvent(event)
				joshSharedAddress = accountCreatedEvent.Address()
				break
			}

			assert.Fail(t, "missing shared account created event")
		}

		for _, event := range createAccountsTxResult.Events {
			if event.Type == lockboxAddr.String()+"Lockbox.UnlockedAccountCreated" {
				// needs work
				accountCreatedEvent := flow.AccountCreatedEvent(event)
				joshSharedAddress = accountCreatedEvent.Address()
				break
			}

			assert.Fail(t, "missing shared account created event")
		}
	})

	t.Run("Should be able to deposit locked tokens to the shared account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateDepositLockedTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, lockboxAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetScript(templates.GenerateCreateLockedDelegatorScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetScript(templates.GenerateCreateLockedDelegatorScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

	t.Run("Should not be able to register as a node operator after registering as a delegator", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateLockedNodeScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			false,
		)
	})

	t.Run("Should be able to delegate locked tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateDelegateNewLockedTokensScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

	})

	t.Run("Should be able to delegate unlocked (staking) tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateDelegateLockedUnlockedTokensScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

	})

	t.Run("Should be able to delegate rewarded tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateDelegateLockedRewardedTokensScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

	})

	t.Run("Should be able to request unstaking", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateUnDelegateLockedTokensScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

	t.Run("Should be able to withdraw unlocked (staking) tokens which are deposited to the locked vault (still locked)", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateWithdrawDelegatorLockedUnlockedTokensScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		// make sure the unlock limit hasn't changed

	})

	t.Run("Should be able to withdraw rewards tokens which are deposited to the locked vault (increase limit)", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateWithdrawDelegatorLockedRewardedTokensScript(lockboxAddr.String(), proxyAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		// make sure the unlock limit has increased by 500.0
	})

}
