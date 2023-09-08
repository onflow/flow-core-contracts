package test

import (
	"context"
	"fmt"
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

func TestStakingProxy(t *testing.T) {

	t.Parallel()

	b, adapter := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, _ := accountKeys.NewWithSigner()
	IDTableCode := contracts.TESTFlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress)

	publicKeys := make([]cadence.Value, 1)

	publicKey, err := sdktemplates.AccountKeyToCadenceCryptoKey(IDTableAccountKey)
	require.NoError(t, err)
	publicKeys[0] = publicKey

	cadencePublicKeys := cadence.NewArray(publicKeys)
	cadenceCode := bytesToCadenceArray(IDTableCode)

	// Deploy the IDTableStaking contract
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateTransferMinterAndDeployScript(env), b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys)).
		AddRawArgument(jsoncdc.MustEncode(CadenceString("FlowIDTableStaking"))).
		AddRawArgument(jsoncdc.MustEncode(cadenceCode))

	_ = tx.AddArgument(CadenceUFix64("1250000.0"))
	_ = tx.AddArgument(CadenceUFix64("0.03"))

	// Construct Array
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
					idTableAddress = flow.Address(event.Value.Fields[0].(cadence.Address))
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

	t.Run("Should be able to set up the admin account", func(t *testing.T) {

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateMintFlowScript(env), b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(lockedTokensAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{},
			[]crypto.Signer{},
			false,
		)
	})

	// Create a new node operator account for staking helper
	nodeAccountKey, nodeSigner := accountKeys.NewWithSigner()
	nodeAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{nodeAccountKey}, nil)

	t.Run("Should be able to set up the node account for staking helper", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetupNodeAccountScript(env), nodeAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{nodeAddress},
			[]crypto.Signer{nodeSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateAddNodeInfoScript(env), nodeAddress)

		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", josh)))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", josh)))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0192d", josh)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{nodeAddress},
			[]crypto.Signer{nodeSigner},
			false,
		)
	})

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
	})

	t.Run("Should be able to register josh as a node operator and add the staking proxy to the node's account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterStakingProxyNodeScript(env), joshAddress)

		_ = tx.AddArgument(cadence.NewAddress(nodeAddress))
		_ = tx.AddArgument(CadenceString(joshID))
		tokenAmount, err := cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)
	})

	t.Run("Should be able to stake locked tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateProxyStakeNewTokensScript(env), nodeAddress)

		_ = tx.AddArgument(CadenceString(joshID))
		tokenAmount, err := cadence.NewUFix64("2000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{nodeAddress},
			[]crypto.Signer{nodeSigner},
			false,
		)
	})

	t.Run("Should be able to stake unlocked (staking) tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateProxyStakeUnstakedTokensScript(env), nodeAddress)

		_ = tx.AddArgument(CadenceString(joshID))
		tokenAmount, err := cadence.NewUFix64("1000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{nodeAddress},
			[]crypto.Signer{nodeSigner},
			false,
		)

	})

	t.Run("Should be able to request unstaking", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateProxyRequestUnstakingScript(env), nodeAddress)

		_ = tx.AddArgument(CadenceString(joshID))
		tokenAmount, err := cadence.NewUFix64("500.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{nodeAddress},
			[]crypto.Signer{nodeSigner},
			false,
		)

	})

	t.Run("Should be able to request unstaking all tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateProxyUnstakeAllScript(env), nodeAddress)

		_ = tx.AddArgument(CadenceString(joshID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{nodeAddress},
			[]crypto.Signer{nodeSigner},
			false,
		)
	})

	t.Run("Should be able to withdraw unlocked (staking) tokens which are deposited to the locked vault (still locked)", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateProxyWithdrawUnstakedScript(env), nodeAddress)

		_ = tx.AddArgument(CadenceString(joshID))
		tokenAmount, err := cadence.NewUFix64("500.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{nodeAddress},
			[]crypto.Signer{nodeSigner},
			false,
		)

	})

	t.Run("Should be able to withdraw rewards tokens which are deposited to the locked vault (increase limit)", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateProxyWithdrawRewardsScript(env), nodeAddress)

		_ = tx.AddArgument(CadenceString(joshID))
		tokenAmount, err := cadence.NewUFix64("500.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{nodeAddress},
			[]crypto.Signer{nodeSigner},
			false,
		)
	})

}
