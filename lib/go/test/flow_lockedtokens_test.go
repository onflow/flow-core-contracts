package test

import (
	"context"
	"fmt"
	"testing"

	"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/onflow/flow-go-sdk/test"
	"github.com/stretchr/testify/assert"
)

func TestLockedTokensStaker(t *testing.T) {
	t.Parallel()
	b, adapter := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
		BurnerAddress:        emulatorServiceAccount,
		StorageFeesAddress:   emulatorServiceAccount,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, _ := accountKeys.NewWithSigner()
	IDTableCode, _ := cadence.NewString(string(contracts.TESTFlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress))[:])

	publicKeys := make([]cadence.Value, 1)

	publicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(IDTableAccountKey)
	require.NoError(t, err)
	publicKeys[0] = publicKey

	cadencePublicKeys := cadence.NewArray(publicKeys)

	// Deploy the IDTableStaking contract
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateTransferMinterAndDeployScript(env), b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys)).
		AddRawArgument(jsoncdc.MustEncode(CadenceString("FlowIDTableStaking")))

	_ = tx.AddArgument(IDTableCode)
	_ = tx.AddArgument(CadenceUFix64("1250000.0"))
	_ = tx.AddArgument(CadenceUFix64("0.03"))
	var candidateNodeLimits []uint64 = []uint64{10, 10, 10, 10, 10}
	candidateLimitsArrayValues := make([]cadence.Value, 5)
	for i, limit := range candidateNodeLimits {
		candidateLimitsArrayValues[i] = cadence.NewUInt64(limit)
	}
	cadenceLimitArray := cadence.NewArray(candidateLimitsArrayValues).WithType(cadence.NewVariableSizedArrayType(cadence.UInt64Type))

	_ = tx.AddArgument(cadenceLimitArray)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{},
		[]crypto.Signer{},
		false,
	)

	var idTableAddress flow.Address

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := adapter.GetEventsForHeightRange(context.Background(), "flow.AccountCreated", i, i)
		for _, result := range results {
			for _, event := range result.Events {
				if event.Type == flow.EventAccountCreated {
					idTableAddress = flow.Address(cadence.SearchFieldByName(event.Value, "address").(cadence.Address))
				}
			}
		}

		i = i + 1
	}

	env.IDTableAddress = idTableAddress.Hex()

	// Deploy the StakingProxy contract
	stakingProxyCode := contracts.FlowStakingProxy()
	stakingProxyAddress, err := adapter.CreateAccount(context.Background(), nil, []sdktemplates.Contract{
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

	env.StakingProxyAddress = stakingProxyAddress.String()

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{adminAccountKey}, nil)

	lockedTokensAccountKey, _ := accountKeys.NewWithSigner()
	lockedTokensAddress := deployLockedTokensContract(t, b, env, idTableAddress, stakingProxyAddress, lockedTokensAccountKey, adminAddress, adminSigner)
	env.LockedTokensAddress = lockedTokensAddress.Hex()

	// Create new keys for the user account
	joshKey, joshSigner := accountKeys.NewWithSigner()

	adminPublicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(adminAccountKey)
	require.NoError(t, err)
	joshPublicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(joshKey)
	require.NoError(t, err)

	var joshSharedAddress flow.Address
	var joshAddress flow.Address

	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateMintFlowScript(env), b.ServiceKey().Address)
	_ = tx.AddArgument(cadence.NewAddress(adminAddress))
	_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{},
		[]crypto.Signer{},
		false,
	)

	t.Run("Should be able to create new shared accounts", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateSharedAccountScript(env), adminAddress).
			AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		createAccountsTxResult, err := adapter.GetTransactionResult(context.Background(), tx.ID())
		assert.NoError(t, err)
		assertEqual(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

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

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCheckSharedRegistrationScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCheckMainRegistrationScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(joshAddress))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)
	})

	// Create a new user account that is not registered
	maxAccountKey, _ := accountKeys.NewWithSigner()
	maxAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{maxAccountKey}, nil)

	t.Run("Should fail because the accounts are not registered", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCheckSharedRegistrationScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(maxAddress))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCheckSharedRegistrationScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(joshAddress))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCheckMainRegistrationScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(maxAddress))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			true,
		)
	})

	t.Run("Should be able to deposit locked tokens to the shared account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositLockedTokensScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// check balance of locked account
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("1000000.0"), result)
	})

	t.Run("Should fail to deposit locked tokens to the user account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositLockedTokensScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(joshAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			true,
		)
	})

	t.Run("Should not be able to withdraw any locked tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateWithdrawTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			true,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// make sure balance of locked account hasn't changed
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("1000000.0"), result)

		// make sure balance of unlocked account hasn't changed
		result = executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)
	})

	t.Run("Should be able to unlock tokens from the shared account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateIncreaseUnlockLimitScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		// Check unlock limit of the shared account
		result := executeScriptAndCheck(t, b,
			templates.GenerateGetUnlockLimitScript(env),
			[][]byte{
				jsoncdc.MustEncode(cadence.Address(joshAddress)),
			},
		)
		assertEqual(t, CadenceUFix64("10000.0"), result)
	})

	t.Run("Should be able to withdraw free tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateWithdrawTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// Check balance of locked account
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("990000.0"), result)

		// check balance of unlocked account
		result = executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("10000.0"), result)

		// withdraw limit should have decreased to zero
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)
	})

	t.Run("Should be able to deposit tokens from the unlocked account and increase withdraw limit", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// Check balance of locked account
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("995000.0"), result)

		// check balance of unlocked account
		result = executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("5000.0"), result)

		// make sure unlock limit has increased by 5000
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("5000.0"), result)
	})

	t.Run("Should be able to register josh as a node operator", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterLockedNodeScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(CadenceString(getNetworkingAddress(josh)))
		_ = tx.AddArgument(CadenceString(getNetworkingAddress(josh)))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0192d", josh)))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%096d", josh)))
		_ = tx.AddArgument(CadenceUFix64("250000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// Check the node ID
		result := executeScriptAndCheck(t, b, templates.GenerateGetNodeIDScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceString(joshID), result)

		// unlock limit should not have changed
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("5000.0"), result)
	})

	t.Run("Should be able to stake locked tokens", func(t *testing.T) {

		script := templates.GenerateStakeNewLockedTokensScript(env)

		tx := createTxWithTemplateAndAuthorizer(b, script, joshAddress)
		_ = tx.AddArgument(CadenceUFix64("2000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		script = templates.GenerateGetLockedAccountBalanceScript(env)

		// Check balance of locked account
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("743000.0"), result)

		// unlock limit should not have changed
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("5000.0"), result)

	})

	t.Run("Should be able to stake unstaked tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStakeLockedUnstakedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("1000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// unlock limit should not have changed
		result := executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("5000.0"), result)

	})

	t.Run("Should be able to stake rewarded tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStakeLockedRewardedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("1000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// Make sure that the unlock limit has increased by 1000.0
		result := executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("6000.0"), result)

	})

	t.Run("Should be able to request unstaking", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeLockedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

	})

	t.Run("Should be able to request unstaking all tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeAllLockedTokensScript(env), joshAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)
	})

	t.Run("Should be able to withdraw unstaked tokens which are deposited to the locked vault (still locked)", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateWithdrawLockedUnstakedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// locked tokens balance should increase by 500
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("743500.0"), result)

		// make sure the unlock limit hasn't changed
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("6000.0"), result)

	})

	t.Run("Should be able to withdraw rewards to the unlocked account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateWithdrawLockedRewardedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// Unlocked account balance should increase by 500
		result := executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("5500.0"), result)

		// Unlock limit should be unchanged
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("6000.0"), result)
	})

	t.Run("Should be able to withdraw rewards to the locked account (increase limit)", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateWithdrawLockedRewardedTokensToLockedAccountScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// Unlocked account balance should remain the same
		result := executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("5500.0"), result)

		// Unlock limit should increase by 500
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("6500.0"), result)
	})

	t.Run("Should be able to register a node with tokens from the locked vault first and then the unlocked vault", func(t *testing.T) {

		result := executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})

		// locked tokens balance should increase by 500
		result = executeScriptAndCheck(t, b,
			templates.GenerateGetLockedAccountBalanceScript(env),
			[][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))},
		)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterLockedNodeScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(CadenceString(getNetworkingAddress(josh)))
		_ = tx.AddArgument(CadenceString(getNetworkingAddress(josh)))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0192d", josh)))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%096d", josh)))
		_ = tx.AddArgument(CadenceUFix64("745000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// Check the node ID
		result = executeScriptAndCheck(t, b, templates.GenerateGetNodeIDScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceString(joshID), result)

		// Check unlocked balance
		result = executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("4500.0"), result)

		// Unlock limit should not have changed
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("7500.0"), result)
	})

	t.Run("Should be able to deposit additional locked tokens to the shared account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositLockedTokensScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("1000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// Check balance of locked account
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("1000.0"), result)
	})

	t.Run("Should be able to stake tokens that come from the locked vault first and then the unlocked vault", func(t *testing.T) {

		script := templates.GenerateStakeNewLockedTokensScript(env)

		tx := createTxWithTemplateAndAuthorizer(b, script, joshAddress)

		_ = tx.AddArgument(CadenceUFix64("2000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// Check balance of locked account
		result := executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshSharedAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		// Check unlocked balance
		result = executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("3500.0"), result)

		// unlock limit should not have changed
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("8500.0"), result)
	})

	t.Run("Should be able to claim leased tokens as the admin", func(t *testing.T) {

		script := templates.GenerateRecoverLeaseTokensScript(env)

		tx := createTxWithTemplateAndAuthorizer(b, script, joshSharedAddress)

		_ = tx.AddArgument(cadence.NewBool(false))
		_ = tx.AddArgument(CadenceUFix64("10.0"))
		_ = tx.AddArgument(cadence.NewAddress(adminAddress))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshSharedAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		// Check balance of locked account
		result := executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshSharedAddress))})
		assertEqual(t, CadenceUFix64("0.0001"), result)

		// Check balance of admin account
		result = executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(adminAddress))})
		assertEqual(t, CadenceUFix64("998999010.00000000"), result)
	})
}

func TestLockedTokensDelegator(t *testing.T) {

	t.Parallel()

	b, adapter := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
		BurnerAddress:        emulatorServiceAccount,
		StorageFeesAddress:   emulatorServiceAccount,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, _ := accountKeys.NewWithSigner()
	IDTableCode, _ := cadence.NewString(string(contracts.TESTFlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress))[:])

	publicKeys := make([]cadence.Value, 1)

	publicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(IDTableAccountKey)
	require.NoError(t, err)
	publicKeys[0] = publicKey

	cadencePublicKeys := cadence.NewArray(publicKeys)

	// Deploy the IDTableStaking contract
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateTransferMinterAndDeployScript(env), b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys)).
		AddRawArgument(jsoncdc.MustEncode(CadenceString("FlowIDTableStaking")))

	_ = tx.AddArgument(IDTableCode)
	_ = tx.AddArgument(CadenceUFix64("1250000.0"))
	_ = tx.AddArgument(CadenceUFix64("0.03"))
	var candidateNodeLimits []uint64 = []uint64{10, 10, 10, 10, 10}
	candidateLimitsArrayValues := make([]cadence.Value, 5)
	for i, limit := range candidateNodeLimits {
		candidateLimitsArrayValues[i] = cadence.NewUInt64(limit)
	}
	cadenceLimitArray := cadence.NewArray(candidateLimitsArrayValues).WithType(cadence.NewVariableSizedArrayType(cadence.UInt64Type))

	_ = tx.AddArgument(cadenceLimitArray)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{},
		[]crypto.Signer{},
		false,
	)

	var idTableAddress flow.Address

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := adapter.GetEventsForHeightRange(context.Background(), "flow.AccountCreated", i, i)

		for _, result := range results {
			for _, event := range result.Events {
				if event.Type == flow.EventAccountCreated {
					idTableAddress = flow.Address(cadence.SearchFieldByName(event.Value, "address").(cadence.Address))
				}
			}
		}

		i = i + 1
	}

	env.IDTableAddress = idTableAddress.Hex()

	// Deploy the StakingProxy contract
	stakingProxyCode := contracts.FlowStakingProxy()
	stakingProxyAddress, err := adapter.CreateAccount(context.Background(), nil, []sdktemplates.Contract{
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

	env.StakingProxyAddress = stakingProxyAddress.Hex()

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{adminAccountKey}, nil)

	lockedTokensAccountKey, _ := accountKeys.NewWithSigner()
	lockedTokensAddress := deployLockedTokensContract(t, b, env, idTableAddress, stakingProxyAddress, lockedTokensAccountKey, adminAddress, adminSigner)

	env.LockedTokensAddress = lockedTokensAddress.Hex()

	// Create new keys for the user account
	joshKey, joshSigner := accountKeys.NewWithSigner()

	adminPublicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(adminAccountKey)
	require.NoError(t, err)
	joshPublicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(joshKey)
	require.NoError(t, err)

	var joshSharedAddress flow.Address
	var joshAddress flow.Address

	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateMintFlowScript(env), b.ServiceKey().Address)
	_ = tx.AddArgument(cadence.NewAddress(adminAddress))
	_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{},
		[]crypto.Signer{},
		false,
	)

	t.Run("Should be able to create new shared accounts", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateSharedAccountScript(env), adminAddress).
			AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		createAccountsTxResult, err := adapter.GetTransactionResult(context.Background(), tx.ID())
		assert.NoError(t, err)
		assertEqual(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

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

	t.Run("Should be able to deposit locked tokens to the shared account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositLockedTokensScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		// check balance of locked account
	})

	t.Run("Should be able to register josh as a delegator", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateLockedDelegatorScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(CadenceUFix64("50000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// Check the delegator ID
		result := executeScriptAndCheck(t, b, templates.GenerateGetDelegatorIDScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, cadence.NewUInt32(1), result)

		// Check the delegator node ID
		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorNodeIDScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceString(joshID), result)
	})

	t.Run("Should be able to delegate locked tokens", func(t *testing.T) {

		script := templates.GenerateDelegateNewLockedTokensScript(env)

		tx := createTxWithTemplateAndAuthorizer(b, script, joshAddress)

		_ = tx.AddArgument(CadenceUFix64("2000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// Check balance of locked account
		result := executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshSharedAddress))})
		assertEqual(t, CadenceUFix64("948000.0"), result)

		// make sure the unlock limit is zero
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)

	})

	t.Run("Should be able to delegate unstaked tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegateLockedUnstakedTokensScript(env), joshAddress)

		_ = tx.AddArgument(CadenceUFix64("1000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// Check balance of locked account
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("948000.0"), result)

		// make sure the unlock limit is zero
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)

	})

	t.Run("Should be able to delegate rewarded tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegateLockedRewardedTokensScript(env), joshAddress)

		_ = tx.AddArgument(CadenceUFix64("1000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// Check balance of locked account. should not have changed
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("948000.0"), result)

		// Make sure that the unlock limit has increased by 1000.0
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("1000.0"), result)

	})

	t.Run("Should be able to request unstaking", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnDelegateLockedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

	})

	t.Run("Should be able to withdraw unstaked tokens which are deposited to the locked vault (still locked)", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateWithdrawDelegatorLockedUnstakedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// Check balance of locked account. should have increased by 500
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("948500.0"), result)

		// unlocked account balance should not increase
		result = executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		// make sure the unlock limit hasn't changed
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("1000.0"), result)

	})

	t.Run("Should be able to withdraw rewards to the unlocked account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateWithdrawDelegatorLockedRewardedTokensScript(env), joshAddress)

		_ = tx.AddArgument(CadenceUFix64("1000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// Locked account balance should be unchanged
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("948500.0"), result)

		// Unlocked account balance should increase by 500
		result = executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("1000.0"), result)

		// Unlock limit should be unchanged
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("1000.0"), result)
	})

	t.Run("Should be able to withdraw rewards to the locked account (increase limit)", func(t *testing.T) {
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateWithdrawDelegatorLockedRewardedTokensToLockedAccountScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// Locked account balance should increase by 500
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("949000.0"), result)

		// Unlocked account balance should be unchanged
		result = executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("1000.0"), result)

		// Unlock limit should increase by 500
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("1500.0"), result)
	})

	t.Run("Should be able to register as a delegator using tokens from the locked vault first and then the unlocked vault", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateLockedDelegatorScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(CadenceUFix64("949500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// Check the delegator ID
		result := executeScriptAndCheck(t, b, templates.GenerateGetDelegatorIDScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, cadence.NewUInt32(1), result)

		// Check the delegator node ID
		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorNodeIDScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceString(joshID), result)

		// Check that unlock limit increases by 500.0
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("2000.0"), result)
	})

	t.Run("Should be able to deposit additional locked tokens to the locked account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositLockedTokensScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("1000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// Check balance of locked account
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("1000.0"), result)
	})

	t.Run("Should be able to delegate tokens from the locked vault first and then the unlocked vault", func(t *testing.T) {

		script := templates.GenerateDelegateNewLockedTokensScript(env)

		tx := createTxWithTemplateAndAuthorizer(b, script, joshAddress)
		_ = tx.AddArgument(CadenceUFix64("1400.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// Check balance of locked account
		result := executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshSharedAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		// Check balance of unlocked account
		result = executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("100.0"), result)

		// Unlock limit should increase by 500
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("2400.0"), result)
	})

	t.Run("Should be able to claim leased tokens as the admin", func(t *testing.T) {

		script := templates.GenerateRecoverLeaseTokensScript(env)

		tx := createTxWithTemplateAndAuthorizer(b, script, joshSharedAddress)

		_ = tx.AddArgument(cadence.NewBool(true))
		_ = tx.AddArgument(CadenceUFix64("10.0"))
		_ = tx.AddArgument(cadence.NewAddress(adminAddress))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshSharedAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		// Check balance of locked account
		result := executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshSharedAddress))})
		assertEqual(t, CadenceUFix64("0.0001"), result)

		// Check balance of admin account
		result = executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(adminAddress))})
		assertEqual(t, CadenceUFix64("998999010.00000000"), result)
	})

	t.Run("Should be able to remove the delegator object from the locked account", func(t *testing.T) {

		script := templates.GenerateRemoveDelegatorScript(env)

		tx := createTxWithTemplateAndAuthorizer(b, script, joshSharedAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress, joshSharedAddress},
			[]crypto.Signer{joshSigner, adminSigner},
			false,
		)

		// Should fail because the delegator does not exist any more
		script = templates.GenerateDelegateNewLockedTokensScript(env)

		tx = createTxWithTemplateAndAuthorizer(b, script, joshAddress)
		_ = tx.AddArgument(CadenceUFix64("10.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			true,
		)

	})

}

func TestCustodyProviderAccountCreation(t *testing.T) {

	t.Parallel()

	b, adapter := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
		BurnerAddress:        emulatorServiceAccount,
		StorageFeesAddress:   emulatorServiceAccount,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, _ := accountKeys.NewWithSigner()
	IDTableCode, _ := cadence.NewString(string(contracts.TESTFlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress))[:])

	publicKeys := make([]cadence.Value, 1)

	publicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(IDTableAccountKey)
	require.NoError(t, err)
	publicKeys[0] = publicKey

	cadencePublicKeys := cadence.NewArray(publicKeys)

	// Deploy the IDTableStaking contract
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateTransferMinterAndDeployScript(env), b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys)).
		AddRawArgument(jsoncdc.MustEncode(CadenceString("FlowIDTableStaking")))

	_ = tx.AddArgument(IDTableCode)
	_ = tx.AddArgument(CadenceUFix64("1250000.0"))
	_ = tx.AddArgument(CadenceUFix64("0.03"))
	var candidateNodeLimits []uint64 = []uint64{10, 10, 10, 10, 10}
	candidateLimitsArrayValues := make([]cadence.Value, 5)
	for i, limit := range candidateNodeLimits {
		candidateLimitsArrayValues[i] = cadence.NewUInt64(limit)
	}
	cadenceLimitArray := cadence.NewArray(candidateLimitsArrayValues).WithType(cadence.NewVariableSizedArrayType(cadence.UInt64Type))

	_ = tx.AddArgument(cadenceLimitArray)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{},
		[]crypto.Signer{},
		false,
	)

	var idTableAddress flow.Address

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := adapter.GetEventsForHeightRange(context.Background(), "flow.AccountCreated", i, i)

		for _, result := range results {
			for _, event := range result.Events {
				if event.Type == flow.EventAccountCreated {
					idTableAddress = flow.Address(cadence.SearchFieldByName(event.Value, "address").(cadence.Address))
				}
			}
		}

		i = i + 1
	}

	env.IDTableAddress = idTableAddress.Hex()

	// Deploy the StakingProxy contract
	stakingProxyCode := contracts.FlowStakingProxy()
	stakingProxyAddress, err := adapter.CreateAccount(context.Background(), nil, []sdktemplates.Contract{
		{
			Name:   "StakingProxy",
			Source: string(stakingProxyCode),
		},
	})
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}

	env.StakingProxyAddress = stakingProxyAddress.Hex()

	_, err = b.CommitBlock()
	assert.NoError(t, err)

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{adminAccountKey}, nil)

	lockedTokensAccountKey, _ := accountKeys.NewWithSigner()
	lockedTokensAddress := deployLockedTokensContract(t, b, env, idTableAddress, stakingProxyAddress, lockedTokensAccountKey, adminAddress, adminSigner)

	env.LockedTokensAddress = lockedTokensAddress.Hex()

	// Create new custody provider account
	custodyAccountKey, custodySigner := accountKeys.NewWithSigner()
	custodyAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{custodyAccountKey}, nil)

	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateMintFlowScript(env), b.ServiceKey().Address)
	_ = tx.AddArgument(cadence.NewAddress(adminAddress))
	_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{},
		[]crypto.Signer{},
		false,
	)

	t.Run("Should be able to set up the custody provider account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetupCustodyAccountScript(env), custodyAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{custodyAddress},
			[]crypto.Signer{custodySigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateMintFlowScript(env), b.ServiceKey().Address)
		_ = tx.AddArgument(cadence.NewAddress(custodyAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{},
			[]crypto.Signer{},
			false,
		)
	})

	t.Run("Should be able to deposit an account creator resource into the custody account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositAccountCreatorScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(custodyAddress))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)
	})

	// Create new keys for the user account
	joshKey, _ := accountKeys.NewWithSigner()

	adminPublicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(adminAccountKey)
	require.NoError(t, err)
	joshPublicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(joshKey)
	require.NoError(t, err)

	var joshSharedAddress flow.Address
	var joshAddress flow.Address

	t.Run("Should be able to create new shared accounts as the custody provider and give the admin the admin capability", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCustodyCreateAccountsScript(env), custodyAddress).
			AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{custodyAddress},
			[]crypto.Signer{custodySigner},
			false,
		)

		createAccountsTxResult, err := adapter.GetTransactionResult(context.Background(), tx.ID())
		assert.NoError(t, err)
		assertEqual(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

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

	t.Run("Unlocked account should be connected to locked account", func(t *testing.T) {
		script := templates.GenerateGetLockedAccountAddressScript(env)

		// Check that locked account is connected to unlocked account
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, cadence.Address(joshSharedAddress), result)
	})

	// Create new keys for a new user account
	maxKey, maxSigner := accountKeys.NewWithSigner()
	maxAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{maxKey}, nil)

	maxPublicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(maxKey)
	require.NoError(t, err)

	var maxSharedAddress flow.Address

	t.Run("Should be able to create a new shared account for an existing account as the custody provider and give the admin the admin capability", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCustodyCreateOnlySharedAccountScript(env), custodyAddress).
			AddAuthorizer(maxAddress).
			AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(maxPublicKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{custodyAddress, maxAddress},
			[]crypto.Signer{custodySigner, maxSigner},
			false,
		)

		createAccountsTxResult, err := adapter.GetTransactionResult(context.Background(), tx.ID())
		assert.NoError(t, err)
		assertEqual(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

		for _, event := range createAccountsTxResult.Events {
			if event.Type == fmt.Sprintf("A.%s.LockedTokens.SharedAccountRegistered", lockedTokensAddress.Hex()) {
				// needs work
				sharedAccountCreatedEvent := sharedAccountRegisteredEvent(event)
				maxSharedAddress = sharedAccountCreatedEvent.Address()
				break
			}
		}
	})

	leaseKey, leaseSigner := accountKeys.NewWithSigner()
	leaseAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{leaseKey}, nil)

	var leaseSharedAddress flow.Address

	t.Run("Should be able to create a new lease shared account for an existing account as the custody provider and give the admin the admin capability", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCustodyCreateOnlyLeaseAccountScript(env), custodyAddress).
			AddAuthorizer(leaseAddress).
			AddRawArgument(jsoncdc.MustEncode(adminPublicKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{custodyAddress, leaseAddress},
			[]crypto.Signer{custodySigner, leaseSigner},
			false,
		)

		createAccountsTxResult, err := adapter.GetTransactionResult(context.Background(), tx.ID())
		assert.NoError(t, err)
		assertEqual(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

		for _, event := range createAccountsTxResult.Events {
			if event.Type == fmt.Sprintf("A.%s.LockedTokens.SharedAccountRegistered", lockedTokensAddress.Hex()) {
				// needs work
				sharedAccountCreatedEvent := sharedAccountRegisteredEvent(event)
				leaseSharedAddress = sharedAccountCreatedEvent.Address()
				break
			}
		}
	})

	t.Run("Should be able to create new shared accounts (with locked account having only 1 x 1000 weight) as the custody provider and give the admin the admin capability", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCustodyCreateAccountWithLeaseAccountScript(env), custodyAddress).
			AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{custodyAddress},
			[]crypto.Signer{custodySigner},
			false,
		)

		createAccountsTxResult, err := adapter.GetTransactionResult(context.Background(), tx.ID())
		assert.NoError(t, err)
		assertEqual(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

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

	t.Run("Should be able to increase the unlock limit for the new accounts", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateIncreaseUnlockLimitScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		// Check unlock limit of the shared account
		result := executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("10000.0"), result)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateIncreaseUnlockLimitScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(maxSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		// Check unlock limit of the shared account
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(maxAddress))})
		assertEqual(t, CadenceUFix64("10000.0"), result)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateIncreaseUnlockLimitScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(leaseSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		// Check unlock limit of the shared account
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(leaseAddress))})
		assertEqual(t, CadenceUFix64("10000.0"), result)
	})

}

func TestLockedTokensRealStaking(t *testing.T) {

	t.Parallel()

	b, adapter := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
		BurnerAddress:        emulatorServiceAccount,
		StorageFeesAddress:   emulatorServiceAccount,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	idTableAddress, _ := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, &env, true, []uint64{10, 10, 10, 10, 10})

	env.IDTableAddress = idTableAddress.Hex()

	// Deploy the StakingProxy contract
	stakingProxyCode := contracts.FlowStakingProxy()
	stakingProxyAddress, err := adapter.CreateAccount(context.Background(), nil, []sdktemplates.Contract{
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

	env.StakingProxyAddress = stakingProxyAddress.String()

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{adminAccountKey}, nil)

	lockedTokensAccountKey, _ := accountKeys.NewWithSigner()
	lockedTokensAddress := deployLockedTokensContract(t, b, env, idTableAddress, stakingProxyAddress, lockedTokensAccountKey, adminAddress, adminSigner)
	env.StakingProxyAddress = stakingProxyAddress.Hex()
	env.LockedTokensAddress = lockedTokensAddress.Hex()

	// Create new keys for the user account
	joshKey, joshSigner := accountKeys.NewWithSigner()

	adminPublicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(adminAccountKey)
	require.NoError(t, err)
	joshPublicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(joshKey)
	require.NoError(t, err)

	var joshSharedAddress flow.Address
	var joshAddress flow.Address

	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateMintFlowScript(env), b.ServiceKey().Address)
	_ = tx.AddArgument(cadence.NewAddress(adminAddress))
	_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{},
		[]crypto.Signer{},
		false,
	)

	t.Run("Should be able to create new shared accounts", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateSharedAccountScript(env), adminAddress).
			AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		createAccountsTxResult, err := adapter.GetTransactionResult(context.Background(), tx.ID())
		assert.NoError(t, err)
		assertEqual(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

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

	t.Run("Should be able to deposit locked tokens to the shared account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositLockedTokensScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)
		// check balance of locked account
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("1000000.0"), result)
	})

	t.Run("Should be able to enable the staking auction", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartStakingScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)
	})

	_, joshStakingKey, joshStakingPOP, _, joshNetworkingKey := generateKeysForNodeRegistration(t)

	t.Run("Should be able to register josh as a node operator", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterLockedNodeScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(CadenceString(getNetworkingAddress(josh)))
		_ = tx.AddArgument(CadenceString(joshNetworkingKey))
		_ = tx.AddArgument(CadenceString(joshStakingKey))
		_ = tx.AddArgument(CadenceString(joshStakingPOP))
		_ = tx.AddArgument(CadenceUFix64("250000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// Check the node ID
		result := executeScriptAndCheck(t, b, templates.GenerateGetNodeIDScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceString(joshID), result)
	})

	t.Run("Should be able to change the networking address", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateLockedNodeUpdateNetworkingAddressScript(env), joshAddress)

		_ = tx.AddArgument(CadenceString(getNetworkingAddress(execution)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNetworkingAddressScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceString(getNetworkingAddress(execution)), result)
	})

	t.Run("Should be able to get the node info from the locked account by just using the address", func(t *testing.T) {
		_ = executeScriptAndCheck(t, b, templates.GenerateGetLockedStakerInfoScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
	})

	t.Run("Should be able to register as a delegator after registering as a node operator", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateLockedDelegatorScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(CadenceUFix64("20000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)
	})

	t.Run("Should be able to stake locked tokens", func(t *testing.T) {

		script := templates.GenerateStakeNewLockedTokensScript(env)
		tx := createTxWithTemplateAndAuthorizer(b, script, joshAddress)
		_ = tx.AddArgument(CadenceUFix64("2000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		script = templates.GenerateGetLockedAccountBalanceScript(env)

		// Check balance of locked account
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("728000.0"), result)

		// unlock limit should not have changed
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)

	})

	t.Run("Should be able to get the delegator info from the locked account by just using the address", func(t *testing.T) {
		_ = executeScriptAndCheck(t, b, templates.GenerateGetLockedDelegatorInfoScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
	})

	t.Run("Should not be able to register a second node while the first has tokens committed", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterLockedNodeScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(maxID))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(CadenceString(getNetworkingAddress(josh)))
		_ = tx.AddArgument(CadenceString(joshNetworkingKey))
		_ = tx.AddArgument(CadenceString(joshStakingKey))
		_ = tx.AddArgument(CadenceString(joshStakingPOP))
		_ = tx.AddArgument(CadenceUFix64("250000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			true,
		)
	})

	t.Run("Should be able to request unstaking", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeLockedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

	})

	t.Run("Should be able to request unstaking all tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeAllLockedTokensScript(env), joshAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)
	})

	t.Run("Should not be able to register a second node while the first has tokens unstaked", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterLockedNodeScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(maxID))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(CadenceString(getNetworkingAddress(josh)))
		_ = tx.AddArgument(CadenceString(joshNetworkingKey))
		_ = tx.AddArgument(CadenceString(joshStakingKey))
		_ = tx.AddArgument(CadenceString(joshStakingPOP))
		_ = tx.AddArgument(CadenceUFix64("250000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			true,
		)
	})

	t.Run("Should be able to withdraw unstaked tokens which are deposited to the locked vault (still locked)", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateWithdrawLockedUnstakedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// locked tokens balance should increase by 500
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("728500.0"), result)

	})

	t.Run("Should be able to register a second node since the first has withdrawn all its tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateWithdrawLockedUnstakedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("251500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		_, maxStakingKey, maxStakingPOP, _, maxNetworkingKey := generateKeysForNodeRegistration(t)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterLockedNodeScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(maxID))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(CadenceString(getNetworkingAddress(max)))
		_ = tx.AddArgument(CadenceString(maxNetworkingKey))
		_ = tx.AddArgument(CadenceString(maxStakingKey))
		_ = tx.AddArgument(CadenceString(maxStakingPOP))
		_ = tx.AddArgument(CadenceUFix64("500000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)
	})
}

func TestLockedTokensRealDelegating(t *testing.T) {

	t.Parallel()

	b, adapter := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
		BurnerAddress:        emulatorServiceAccount,
		StorageFeesAddress:   emulatorServiceAccount,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	idTableAddress, _ := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, &env, true, []uint64{10, 10, 10, 10, 10})

	env.IDTableAddress = idTableAddress.Hex()

	// Deploy the StakingProxy contract
	stakingProxyCode := contracts.FlowStakingProxy()
	stakingProxyAddress, err := adapter.CreateAccount(context.Background(), nil, []sdktemplates.Contract{
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

	env.StakingProxyAddress = stakingProxyAddress.Hex()
	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{adminAccountKey}, nil)
	lockedTokensAccountKey, _ := accountKeys.NewWithSigner()
	lockedTokensAddress := deployLockedTokensContract(t, b, env, idTableAddress, stakingProxyAddress, lockedTokensAccountKey, adminAddress, adminSigner)
	env.LockedTokensAddress = lockedTokensAddress.Hex()

	// Create new keys for the user account
	joshKey, joshSigner := accountKeys.NewWithSigner()

	adminPublicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(adminAccountKey)
	require.NoError(t, err)
	joshPublicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(joshKey)
	require.NoError(t, err)

	var joshSharedAddress flow.Address
	var joshAddress flow.Address

	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateMintFlowScript(env), b.ServiceKey().Address)
	_ = tx.AddArgument(cadence.NewAddress(adminAddress))
	_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{},
		[]crypto.Signer{},
		false,
	)

	t.Run("Should be able to create new shared accounts", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateSharedAccountScript(env), adminAddress).
			AddRawArgument(jsoncdc.MustEncode(adminPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey)).
			AddRawArgument(jsoncdc.MustEncode(joshPublicKey))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)

		createAccountsTxResult, err := adapter.GetTransactionResult(context.Background(), tx.ID())
		assert.NoError(t, err)
		assertEqual(t, flow.TransactionStatusSealed, createAccountsTxResult.Status)

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

	t.Run("Should be able to deposit locked tokens to the shared account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositLockedTokensScript(env), adminAddress)
		_ = tx.AddArgument(cadence.NewAddress(joshSharedAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminAddress},
			[]crypto.Signer{adminSigner},
			false,
		)
	})

	t.Run("Should be able to enable the staking auction", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartStakingScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)
	})

	t.Run("Should be able to register as a node operator", func(t *testing.T) {

		_, joshStakingKey, joshStakingPOP, _, joshNetworkingKey := generateKeysForNodeRegistration(t)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterLockedNodeScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(CadenceString(getNetworkingAddress(josh)))
		_ = tx.AddArgument(CadenceString(joshNetworkingKey))
		_ = tx.AddArgument(CadenceString(joshStakingKey))
		_ = tx.AddArgument(CadenceString(joshStakingPOP))
		_ = tx.AddArgument(CadenceUFix64("320000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)
	})

	t.Run("Should be able to register josh as a delegator", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateLockedDelegatorScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(CadenceUFix64("50000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)
	})

	t.Run("Should not be able to register josh as a new delegator since there are still tokens in committed", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateLockedDelegatorScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(CadenceUFix64("50000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			true,
		)
	})

	t.Run("Should be able to delegate locked tokens", func(t *testing.T) {

		script := templates.GenerateDelegateNewLockedTokensScript(env)
		tx := createTxWithTemplateAndAuthorizer(b, script, joshAddress)
		_ = tx.AddArgument(CadenceUFix64("2000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// Check balance of locked account
		result := executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshSharedAddress))})
		assertEqual(t, CadenceUFix64("628000.0"), result)

		// make sure the unlock limit is zero
		result = executeScriptAndCheck(t, b, templates.GenerateGetUnlockLimitScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)
	})

	t.Run("Should be able to request unstaking", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnDelegateLockedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)
	})

	t.Run("Should not be able to register josh as a delegator while there are still tokens committed or unstaked", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateLockedDelegatorScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(CadenceUFix64("50000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			true,
		)
	})

	t.Run("Should be able to withdraw unstaked tokens which are deposited to the locked vault (still locked)", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateWithdrawDelegatorLockedUnstakedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		script := templates.GenerateGetLockedAccountBalanceScript(env)

		// Check balance of locked account. should have increased by 500
		result := executeScriptAndCheck(t, b, script, [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("628500.0"), result)

		// unlocked account balance should not increase
		result = executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)

	})

	t.Run("Should not be able to register josh as a new delegator since there are still tokens in staking", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateLockedDelegatorScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(CadenceUFix64("50000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			true,
		)
	})

	t.Run("Should not be able to register josh as a delegator since all tokens have been withdrawn from staking", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnDelegateLockedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("51500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateWithdrawDelegatorLockedUnstakedTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("51500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateLockedDelegatorScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(CadenceUFix64("50000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		// total balance among all accounts
		result := executeScriptAndCheck(t, b, templates.GenerateGetTotalBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("1000000.0"), result)
	})
}
