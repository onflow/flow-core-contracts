package test

import (
	"fmt"
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/cadence/runtime/interpreter"

	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/stretchr/testify/require"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

func TestStakingCollectionDeploy(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)
	_ = deployAllCollectionContracts(t, b, accountKeys, &env)
}

func TestStakingCollectionGetTokens(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)
	_ = deployAllCollectionContracts(t, b, accountKeys, &env)

	// create regular account

	regAccountAddress, _, regAccountSigner := newAccountWithAddress(b, accountKeys)

	// Add 1Billion tokens to regular account
	mintTokensForAccount(t, b, regAccountAddress, "1000000000.0")

	// add a staking collection to a regular account with no locked account
	t.Run("should be able to setup an account with a staking collection", func(t *testing.T) {

		addStakingCollectionToRegAcctWithNoLockedAcctTx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), regAccountAddress)

		signAndSubmit(
			t, b, addStakingCollectionToRegAcctWithNoLockedAcctTx,
			[]flow.Address{b.ServiceKey().Address, regAccountAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), regAccountSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     regAccountAddress.String(),
			unlockedBalance:    "1000000000.0",
			lockedBalance:      "",
			unlockedTokensUsed: "0.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "",
			nodes:              []string{},
			delegators:         []DelegatorIDs{},
		})
	})

	t.Run("should be able to get tokens with sufficient balance in normal account", func(t *testing.T) {
		// get tokens with insufficient balance
		// should fail
		getTokensWithInsufficientBalanceTx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionGetTokensScript(env), regAccountAddress)
		_ = getTokensWithInsufficientBalanceTx.AddArgument(CadenceUFix64("1000000001.0"))

		signAndSubmit(
			t, b, getTokensWithInsufficientBalanceTx,
			[]flow.Address{b.ServiceKey().Address, regAccountAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), regAccountSigner},
			true,
		)

		// get tokens with sufficient balance
		getTokensWithSufficientBalanceTx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionGetTokensScript(env), regAccountAddress)
		_ = getTokensWithSufficientBalanceTx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, getTokensWithSufficientBalanceTx,
			[]flow.Address{b.ServiceKey().Address, regAccountAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), regAccountSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     regAccountAddress.String(),
			unlockedBalance:    "0.0",
			lockedBalance:      "",
			unlockedTokensUsed: "1000000000.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "",
			nodes:              []string{},
			delegators:         []DelegatorIDs{},
		})
	})

	// Create a locked account pair with only tokens in the locked account
	joshAddress, _, joshSigner := createLockedAccountPairWithBalances(
		t, b,
		accountKeys,
		env,
		"1000.0", "0.0")

	// add a staking collection to the main account
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), joshAddress)
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, joshAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
		false,
	)

	// get tokens with insufficient balance
	t.Run("should be able to get tokens with sufficient balance in locked account", func(t *testing.T) {
		// Should fail because the amount is too high
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionGetTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("1000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// Should succeed because the amount is enough
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionGetTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("100.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "0.0",
			lockedBalance:      "900.0",
			unlockedTokensUsed: "0.0",
			lockedTokensUsed:   "100.0",
			unlockLimit:        "0.0",
			nodes:              []string{},
			delegators:         []DelegatorIDs{},
		})
	})

	// Create a locked account pair with only tokens in the unlocked account
	maxAddress, _, maxSigner := createLockedAccountPairWithBalances(
		t, b,
		accountKeys,
		env,
		"0.0", "1000.0")

	// add a staking collection to the main account
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), maxAddress)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, maxAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
		false,
	)

	// get tokens with insufficient balance
	t.Run("should be able to get tokens with sufficient balance in the unlocked account", func(t *testing.T) {
		// Should fail because the amount is too high
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionGetTokensScript(env), maxAddress)
		_ = tx.AddArgument(CadenceUFix64("1000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			true,
		)

		// Should succeed because the amount is enough
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionGetTokensScript(env), maxAddress)
		_ = tx.AddArgument(CadenceUFix64("100.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     maxAddress.String(),
			unlockedBalance:    "900.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "100.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "0.0",
			nodes:              []string{},
			delegators:         []DelegatorIDs{},
		})
	})

	// Create a locked account pair with tokens in both accounts
	jeffAddress, _, jeffSigner := createLockedAccountPairWithBalances(
		t, b,
		accountKeys,
		env,
		"1000.0", "1000.0")

	// add a staking collection to the main account
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), jeffAddress)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, jeffAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner},
		false,
	)

	t.Run("should be able to get tokens with sufficient balance in both accounts", func(t *testing.T) {
		// Should fail because there is enough in locked account, but not enough in unlocked account
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionGetTokensScript(env), jeffAddress)
		_ = tx.AddArgument(CadenceUFix64("1000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner},
			true,
		)

		// Should succeed because there is enough sum in both accounts, should increase both used numbers
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionGetTokensScript(env), jeffAddress)
		_ = tx.AddArgument(CadenceUFix64("1500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress.String(),
			unlockedBalance:    "500.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "500.0",
			lockedTokensUsed:   "1000.0",
			unlockLimit:        "0.0",
			nodes:              []string{},
			delegators:         []DelegatorIDs{},
		})
	})
}

func TestStakingCollectionDepositTokens(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)
	_ = deployAllCollectionContracts(t, b, accountKeys, &env)

	// create regular account
	regAccountAddress, _, regAccountSigner := newAccountWithAddress(b, accountKeys)
	// Add 1Billion tokens to regular account
	mintTokensForAccount(t, b, regAccountAddress, "1000000000.0")
	addStakingCollectionToRegAcctWithNoLockedAcctTx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), regAccountAddress)
	signAndSubmit(
		t, b, addStakingCollectionToRegAcctWithNoLockedAcctTx,
		[]flow.Address{b.ServiceKey().Address, regAccountAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), regAccountSigner},
		false,
	)

	t.Run("should be able to get and deposit tokens from just normal account", func(t *testing.T) {
		// deposit tokens with sufficient balance
		getTokensWithSufficientBalanceTx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionDepositTokensScript(env), regAccountAddress)
		_ = getTokensWithSufficientBalanceTx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, getTokensWithSufficientBalanceTx,
			[]flow.Address{b.ServiceKey().Address, regAccountAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), regAccountSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     regAccountAddress.String(),
			unlockedBalance:    "1000000000.0",
			lockedBalance:      "",
			unlockedTokensUsed: "0.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "",
			nodes:              []string{},
			delegators:         []DelegatorIDs{},
		})
	})

	// Create a locked account pair with only tokens in the locked account
	joshAddress, _, joshSigner := createLockedAccountPairWithBalances(
		t, b,
		accountKeys,
		env,
		"1000.0", "0.0")

	// add a staking collection to the main account
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), joshAddress)
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, joshAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
		false,
	)

	t.Run("should be able to get and deposit tokens with sufficient balance in locked account", func(t *testing.T) {
		// Should succeed because the amount is enough
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionDepositTokensScript(env), joshAddress)
		_ = tx.AddArgument(CadenceUFix64("100.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "0.0",
			lockedBalance:      "1000.0",
			unlockedTokensUsed: "0.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "0.0",
			nodes:              []string{},
			delegators:         []DelegatorIDs{},
		})
	})

	// Create a locked account pair with tokens in both accounts
	jeffAddress, _, jeffSigner := createLockedAccountPairWithBalances(
		t, b,
		accountKeys,
		env,
		"1000.0", "1000.0")
	// add a staking collection to the main account
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), jeffAddress)
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, jeffAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner},
		false,
	)

	t.Run("should be able to get tokens with sufficient balance in both accounts", func(t *testing.T) {

		// Should succeed because there is enough sum in both accounts, should increase both used numbers
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionDepositTokensScript(env), jeffAddress)
		_ = tx.AddArgument(CadenceUFix64("1500.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress.String(),
			unlockedBalance:    "1000.0",
			lockedBalance:      "1000.0",
			unlockedTokensUsed: "0.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "0.0",
			nodes:              []string{},
			delegators:         []DelegatorIDs{},
		})
	})
}

func TestStakingCollectionRegisterNode(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)
	IDTableSigner := deployAllCollectionContracts(t, b, accountKeys, &env)

	// Create regular accounts
	userAddresses, _, userSigners := registerAndMintManyAccounts(t, b, accountKeys, 4)

	var amountToCommit interpreter.UFix64Value = 48000000000000

	// and register a normal node outside of the collection
	registerNode(t, b, env,
		userAddresses[0],
		userSigners[0],
		adminID,
		fmt.Sprintf("%0128d", admin),
		fmt.Sprintf("%0128d", admin),
		fmt.Sprintf("%0192d", admin),
		amountToCommit,
		amountToCommit,
		1,
		false)

	// register a normal delegator outside of the collection
	registerDelegator(t, b, env,
		userAddresses[0],
		userSigners[0],
		adminID,
		false)

	// end staking auction and epoch, then pay rewards
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), flow.HexToAddress(env.IDTableAddress))
	err := tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID)}))
	require.NoError(t, err)
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, flow.HexToAddress(env.IDTableAddress)},
		[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
		false,
	)
	tx = createTxWithTemplateAndAuthorizer(b, templates.GeneratePayRewardsScript(env), flow.HexToAddress(env.IDTableAddress))
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, flow.HexToAddress(env.IDTableAddress)},
		[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
		false,
	)

	t.Run("Should be able to set up staking collection, which moves the node and delegator to the collection", func(t *testing.T) {

		// setup the staking collection which should put the normal node and delegator in the collection
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), userAddresses[0])

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, userAddresses[0]},
			[]crypto.Signer{b.ServiceKey().Signer(), userSigners[0]},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     userAddresses[0].String(),
			unlockedBalance:    "999520000.0",
			lockedBalance:      "",
			unlockedTokensUsed: "480000.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "",
			nodes:              []string{adminID},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: adminID, id: 1}},
		})

		// should be false if the node doesn't exist
		result := executeScriptAndCheck(t, b, templates.GenerateCollectionGetDoesStakeExistScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(userAddresses[0])), jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.NewOptional(nil))})
		assertEqual(t, cadence.NewBool(false), result)

		// should be false if the delegator doesn't exist
		result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetDoesStakeExistScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(userAddresses[0])), jsoncdc.MustEncode(cadence.String(adminID)), jsoncdc.MustEncode(cadence.NewOptional(cadence.NewUInt32(2)))})
		assertEqual(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64("1249999.9968"), result)
	})

	// Create a locked account pair with tokens in both accounts
	joshAddress, _, joshSigner := createLockedAccountPairWithBalances(
		t, b,
		accountKeys,
		env,
		"1000000.0", "1000000.0")

	// Register a node and a delegator in the locked account
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterLockedNodeScript(env), joshAddress)
	_ = tx.AddArgument(cadence.NewString(joshID))
	_ = tx.AddArgument(cadence.NewUInt8(4))
	_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", josh)))
	_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", josh)))
	_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", josh)))
	_ = tx.AddArgument(CadenceUFix64("320000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, joshAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
		false,
	)

	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateLockedDelegatorScript(env), joshAddress)
	_ = tx.AddArgument(cadence.NewString(joshID))
	_ = tx.AddArgument(CadenceUFix64("50000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, joshAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
		false,
	)

	t.Run("Should be able to setup staking collection which recognizes the locked staking objects", func(t *testing.T) {

		// add a staking collection to the main account
		// the node and delegator in the locked account should be accesible through the staking collection
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), joshAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "1000000.0",
			lockedBalance:      "630000.0",
			unlockedTokensUsed: "0.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "0.0",
			nodes:              []string{joshID},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: joshID, id: 1}},
		})

		// should be false if the node doesn't exist
		result := executeScriptAndCheck(t, b, templates.GenerateCollectionGetDoesStakeExistScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress)), jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.NewOptional(nil))})
		assertEqual(t, cadence.NewBool(false), result)

		// should be false if the delegator doesn't exist
		result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetDoesStakeExistScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress)), jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.NewOptional(cadence.NewUInt32(2)))})
		assertEqual(t, cadence.NewBool(false), result)

	})

	t.Run("Should be able to register a second node and delegator in the staking collection", func(t *testing.T) {

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterNode(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(maxID))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", max)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", max)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", max)))
		_ = tx.AddArgument(CadenceUFix64("500000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterDelegator(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(maxID))
		_ = tx.AddArgument(CadenceUFix64("500000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "630000.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "370000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "0.0",
			nodes:              []string{maxID, joshID},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: maxID, id: 1}, DelegatorIDs{nodeID: joshID, id: 1}},
		})
	})
}

func TestStakingCollectionStakeTokens(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)
	_ = deployAllCollectionContracts(t, b, accountKeys, &env)

	joshAddress, _, joshSigner, joshID1, joshID2 := registerStakingCollectionNodesAndDelegators(
		t, b,
		accountKeys,
		env,
		"1000000.0", "1000000.0")

	t.Run("Should be able to commit new tokens to the node or delegator in both accounts", func(t *testing.T) {

		// Should fail because stake doesn't exist
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeNewTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(accessID))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// Stake new tokens to the locked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeNewTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Stake new tokens to the unlocked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeNewTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Stake new tokens to the locked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeNewTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Stake new tokens to the unlocked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeNewTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "590000.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "390000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "20000.0",
			nodes:              []string{joshID2, joshID1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: joshID2, id: 1}, DelegatorIDs{nodeID: joshID1, id: 1}},
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              0,
			tokensCommitted:          "330000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "0.0",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              0,
			tokensCommitted:          "510000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "0.0",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              1,
			tokensCommitted:          "60000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "0.0",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              1,
			tokensCommitted:          "510000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "0.0",
		})
	})

	t.Run("Should be able to unstake tokens from the node or delegator in both accounts", func(t *testing.T) {

		// Should fail because stake doesn't exist
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRequestUnstaking(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(accessID))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// unstake tokens from the locked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRequestUnstaking(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// unstake tokens from the unlocked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRequestUnstaking(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// unstake tokens from the locked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRequestUnstaking(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// unstake tokens from the unlocked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRequestUnstaking(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "590000.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "390000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "20000.0",
			nodes:              []string{joshID2, joshID1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: joshID2, id: 1}, DelegatorIDs{nodeID: joshID1, id: 1}},
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              0,
			tokensCommitted:          "320000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "10000.0",
			tokensRewarded:           "0.0",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              0,
			tokensCommitted:          "500000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "10000.0",
			tokensRewarded:           "0.0",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              1,
			tokensCommitted:          "50000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "10000.0",
			tokensRewarded:           "0.0",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              1,
			tokensCommitted:          "500000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "10000.0",
			tokensRewarded:           "0.0",
		})
	})

	t.Run("Should be able to stake unstaked tokens from the node or delegator in both accounts", func(t *testing.T) {

		// Should fail because stake doesn't exist
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeUnstakedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(accessID))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// Stake unstaked tokens to the locked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeUnstakedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Stake unstaked tokens to the unlocked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeUnstakedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Stake unstaked tokens to the locked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeUnstakedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Stake unstaked tokens to the unlocked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeUnstakedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "590000.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "390000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "20000.0",
			nodes:              []string{joshID2, joshID1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: joshID2, id: 1}, DelegatorIDs{nodeID: joshID1, id: 1}},
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              0,
			tokensCommitted:          "325000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "5000.0",
			tokensRewarded:           "0.0",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              0,
			tokensCommitted:          "505000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "5000.0",
			tokensRewarded:           "0.0",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              1,
			tokensCommitted:          "55000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "5000.0",
			tokensRewarded:           "0.0",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              1,
			tokensCommitted:          "505000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "5000.0",
			tokensRewarded:           "0.0",
		})
	})

	t.Run("Should be able to withdraw unstaked tokens from the node or delegator in both accounts", func(t *testing.T) {

		// Should fail because stake doesn't exist
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionWithdrawUnstakedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(accessID))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// withdraw unstaked tokens from locked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionWithdrawUnstakedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// withdraw unstaked tokens from the unlocked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionWithdrawUnstakedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// withdraw unstaked tokens from the locked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionWithdrawUnstakedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// withdraw unstaked tokens from the unlocked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionWithdrawUnstakedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "600000.0",
			lockedBalance:      "10000.0",
			unlockedTokensUsed: "380000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "20000.0",
			nodes:              []string{joshID2, joshID1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: joshID2, id: 1}, DelegatorIDs{nodeID: joshID1, id: 1}},
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              0,
			tokensCommitted:          "325000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "0.0",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              0,
			tokensCommitted:          "505000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "0.0",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              1,
			tokensCommitted:          "55000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "0.0",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              1,
			tokensCommitted:          "505000.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "0.0",
		})
	})
}

func TestStakingCollectionRewards(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)
	IDTableSigner := deployAllCollectionContracts(t, b, accountKeys, &env)

	joshAddress, _, joshSigner, joshID1, joshID2 := registerStakingCollectionNodesAndDelegators(
		t, b,
		accountKeys,
		env,
		"1000000.0", "1000000.0")

	// end staking auction and epoch, then pay rewards
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), flow.HexToAddress(env.IDTableAddress))
	err := tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString(joshID1), cadence.NewString(joshID2)}))
	require.NoError(t, err)
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, flow.HexToAddress(env.IDTableAddress)},
		[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
		false,
	)
	tx = createTxWithTemplateAndAuthorizer(b, templates.GeneratePayRewardsScript(env), flow.HexToAddress(env.IDTableAddress))
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, flow.HexToAddress(env.IDTableAddress)},
		[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
		false,
	)

	t.Run("Should be able to withdraw rewarded tokens from the node or delegator in both accounts", func(t *testing.T) {

		// Should fail because stake doesn't exist
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionWithdrawRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(accessID))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// withdraw rewarded tokens to the locked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionWithdrawRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// withdraw rewarded tokens to the unlocked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionWithdrawRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// withdraw rewarded tokens to the locked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionWithdrawRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// withdraw rewarded tokens to the unlocked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionWithdrawRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "650000.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "370000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "0.0",
			nodes:              []string{joshID2, joshID1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: joshID2, id: 1}, DelegatorIDs{nodeID: joshID1, id: 1}},
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              0,
			tokensCommitted:          "0.0",
			tokensStaked:             "320000.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "290620.435",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              0,
			tokensCommitted:          "0.0",
			tokensStaked:             "500000.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "487700.725",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              1,
			tokensCommitted:          "0.0",
			tokensStaked:             "50000.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "36970.8025",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              1,
			tokensCommitted:          "0.0",
			tokensStaked:             "500000.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "414708.025",
		})
	})

	t.Run("Should be able to stake rewarded tokens for the node or delegator in both accounts", func(t *testing.T) {

		// Should fail because stake doesn't exist
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(accessID))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// stake rewarded tokens to the locked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// stake rewarded tokens to the unlocked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// stake rewarded tokens to the locked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// stake rewarded tokens to the unlocked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "650000.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "380000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "10000.0",
			nodes:              []string{joshID2, joshID1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: joshID2, id: 1}, DelegatorIDs{nodeID: joshID1, id: 1}},
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              0,
			tokensCommitted:          "5000.0",
			tokensStaked:             "320000.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "285620.435",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              0,
			tokensCommitted:          "5000.0",
			tokensStaked:             "500000.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "482700.725",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              1,
			tokensCommitted:          "5000.0",
			tokensStaked:             "50000.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "31970.8025",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              1,
			tokensCommitted:          "5000.0",
			tokensStaked:             "500000.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "0.0",
			tokensRewarded:           "409708.025",
		})
	})

	t.Run("Should be able to unstake All tokens from node in locked and unlocked accounts", func(t *testing.T) {

		// Should fail because stake doesn't exist
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionUnstakeAll(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(accessID))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// unstake all tokens to the locked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionUnstakeAll(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// unstake all tokens to the unlocked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionUnstakeAll(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// unstakeAll to the locked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionUnstakeAll(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewUInt32(1))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// unstakeAll to the unlocked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionUnstakeAll(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewUInt32(1))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "650000.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "380000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "10000.0",
			nodes:              []string{joshID2, joshID1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: joshID2, id: 1}, DelegatorIDs{nodeID: joshID1, id: 1}},
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              0,
			tokensCommitted:          "0.0",
			tokensStaked:             "320000.0",
			tokensRequestedToUnstake: "320000.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "5000.0",
			tokensRewarded:           "285620.435",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              0,
			tokensCommitted:          "0.0",
			tokensStaked:             "500000.0",
			tokensRequestedToUnstake: "500000.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "5000.0",
			tokensRewarded:           "482700.725",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              1,
			tokensCommitted:          "0.0",
			tokensStaked:             "50000.0",
			tokensRequestedToUnstake: "50000.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "5000.0",
			tokensRewarded:           "31970.8025",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID2,
			delegatorID:              1,
			tokensCommitted:          "0.0",
			tokensStaked:             "500000.0",
			tokensRequestedToUnstake: "500000.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "5000.0",
			tokensRewarded:           "409708.025",
		})
	})
}

func TestStakingCollectionCloseStake(t *testing.T) {

	b, accountKeys, env := newTestSetup(t)
	IDTableSigner := deployAllCollectionContracts(t, b, accountKeys, &env)

	joshAddress, _, joshSigner, joshID1, joshID2 := registerStakingCollectionNodesAndDelegators(
		t, b,
		accountKeys,
		env,
		"1000000.0", "1000000.0")

	t.Run("Should fail to close a stake and delegation stored in the locked account if there are tokens in a 'staked' state", func(t *testing.T) {

		// Should fail because node isn't ready to be closed. tokens in committed bucket
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// Should fail because node isn't ready to be closed.
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// End staking auction and epoch
		endStakingMoveTokens(t, b, env, flow.HexToAddress(env.IDTableAddress), IDTableSigner,
			[]cadence.Value{cadence.NewString(joshID1), cadence.NewString(joshID2)},
		)

		// Should fail because node isn't ready to be closed. tokens in staked bucket
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// Should fail because node isn't ready to be closed. tokens in staked
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "630000.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "370000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "0.0",
			nodes:              []string{joshID2, joshID1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: joshID2, id: 1}, DelegatorIDs{nodeID: joshID1, id: 1}},
		})

		// Request Unstaking all staked tokens from joshID1
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionUnstakeAll(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Request Unstaking all delegated tokens to joshID1
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRequestUnstaking(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))
		_ = tx.AddArgument(CadenceUFix64("50000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Request Unstaking all delegated tokens to joshID2
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRequestUnstaking(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))
		_ = tx.AddArgument(CadenceUFix64("500000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Request Unstaking all staked tokens from joshID2
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionUnstakeAll(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// End staking auction and epoch
		endStakingMoveTokens(t, b, env, flow.HexToAddress(env.IDTableAddress), IDTableSigner,
			[]cadence.Value{cadence.NewString(joshID1), cadence.NewString(joshID2)},
		)

		// Should fail because node isn't ready to be closed. tokens in unstaking bucket
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// Should fail because node isn't ready to be closed. tokens in unstaking
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		endStakingMoveTokens(t, b, env, flow.HexToAddress(env.IDTableAddress), IDTableSigner,
			[]cadence.Value{cadence.NewString(joshID1), cadence.NewString(joshID2)},
		)

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              1,
			tokensCommitted:          "0.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "50000.0",
			tokensRewarded:           "0.0",
		})

		verifyStakingInfo(t, b, env, StakingInfo{
			nodeID:                   joshID1,
			delegatorID:              0,
			tokensCommitted:          "0.0",
			tokensStaked:             "0.0",
			tokensRequestedToUnstake: "0.0",
			tokensUnstaking:          "0.0",
			tokensUnstaked:           "320000.0",
			tokensRewarded:           "0.0",
		})

		// Should close stake for the node becuase all tokens are able to be withdrawn
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "630000.0",
			lockedBalance:      "320000.0",
			unlockedTokensUsed: "370000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "0.0",
			nodes:              []string{joshID2},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: joshID2, id: 1}, DelegatorIDs{nodeID: joshID1, id: 1}},
		})

		// should close stake for the delegator because all tokens are able to be withdrawn
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "630000.0",
			lockedBalance:      "370000.0",
			unlockedTokensUsed: "370000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "0.0",
			nodes:              []string{joshID2},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: joshID2, id: 1}},
		})

		// Should close stake because tokens are able to be withdrawn
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(cadence.NewString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "1000000.0",
			lockedBalance:      "1000000.0",
			unlockedTokensUsed: "0.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "0.0",
			nodes:              []string{},
			delegators:         []DelegatorIDs{},
		})
	})

}

func TestDoesAccountHaveStakingCollection(t *testing.T) {

	b, accountKeys, env := newTestSetup(t)
	_ = deployAllCollectionContracts(t, b, accountKeys, &env)

	t.Run("Should fail because account was not created with staking collection", func(t *testing.T) {
		joshAddress, _, _ := createLockedAccountPairWithBalances(
			t, b,
			accountKeys,
			env,
			"1000000.0", "1000000.0")

		result := executeScriptAndCheck(t, b, templates.GenerateCollectionDoesAccountHaveStakingCollection(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, cadence.NewBool(false), result)
	})

	t.Run("Should fail because account was not created with staking collection", func(t *testing.T) {
		joshAddress, _, _, _, _ := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"1000000.0", "1000000.0")

		result := executeScriptAndCheck(t, b, templates.GenerateCollectionDoesAccountHaveStakingCollection(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, cadence.NewBool(true), result)
	})
}

func TestStakingCollectionRemoveNodeStaker(t *testing.T) {

	b, accountKeys, env := newTestSetup(t)
	_ = deployAllCollectionContracts(t, b, accountKeys, &env)

	t.Run("Should fail to transfer a node staker because account uses locked tokens", func(t *testing.T) {
		jeffAddress1, _, jeffSigner1, jeffID1_1, _ := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"1000000.0", "1000000.0")

		jeffAddress2, _, _, _, _ := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"1000000.0", "1000000.0")

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionTransferNode(env), jeffAddress1)
		_ = tx.AddArgument(cadence.NewString(jeffID1_1))
		_ = tx.AddArgument(cadence.NewAddress(jeffAddress2))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress1},
			[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner1},
			true,
		)
	})

	t.Run("Should fail to transfer a node delegator because account uses locked tokens", func(t *testing.T) {
		jeffAddress1, _, jeffSigner1, jeffID1_1, _ := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"1000000.0", "1000000.0")

		jeffAddress2, _, _, _, _ := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"1000000.0", "1000000.0")

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionTransferDelegator(env), jeffAddress1)
		_ = tx.AddArgument(cadence.NewString(jeffID1_1))
		_ = tx.AddArgument(cadence.NewAddress(jeffAddress2))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress1},
			[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner1},
			true,
		)
	})

	t.Run("Should be able to transfer a node staker stored in Staking Collection between accounts.", func(t *testing.T) {
		jeffAddress1, _, jeffSigner1, jeffID1_1, jeffID1_2 := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"0.0", "2000000.0")

		jeffAddress2, _, _, jeffID2_1, jeffID2_2 := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"0.0", "2000000.0")

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress1.String(),
			unlockedBalance:    "630000.00000000",
			lockedBalance:      "0.00000000",
			unlockedTokensUsed: "1000000.00000000",
			lockedTokensUsed:   "0.00000000",
			unlockLimit:        "370000.00000000",
			nodes:              []string{jeffID1_2, jeffID1_1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: jeffID1_2, id: 1}, DelegatorIDs{nodeID: jeffID1_1, id: 1}},
		})

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress2.String(),
			unlockedBalance:    "630000.00000000",
			lockedBalance:      "0.00000000",
			unlockedTokensUsed: "1000000.00000000",
			lockedTokensUsed:   "0.00000000",
			unlockLimit:        "370000.00000000",
			nodes:              []string{jeffID2_2, jeffID2_1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: jeffID2_2, id: 1}, DelegatorIDs{nodeID: jeffID2_1, id: 1}},
		})

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionTransferNode(env), jeffAddress1)
		_ = tx.AddArgument(cadence.NewString(jeffID1_2))
		_ = tx.AddArgument(cadence.NewAddress(jeffAddress2))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress1},
			[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner1},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress2.String(),
			unlockedBalance:    "630000.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "1500000.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "370000.0",
			nodes:              []string{jeffID2_2, jeffID1_2, jeffID2_1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: jeffID2_2, id: 1}, DelegatorIDs{nodeID: jeffID2_1, id: 1}},
		})
	})

	t.Run("Should be able to transfer a delegator stored in Staking Collection between accounts.", func(t *testing.T) {
		jeffAddress1, _, jeffSigner1, jeffID1_1, jeffID1_2 := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"0.0", "2000000.0")

		jeffAddress2, _, _, jeffID2_1, jeffID2_2 := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"0.0", "2000000.0")

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress1.String(),
			unlockedBalance:    "630000.00000000",
			lockedBalance:      "0.00000000",
			unlockedTokensUsed: "1000000.00000000",
			lockedTokensUsed:   "0.00000000",
			unlockLimit:        "370000.00000000",
			nodes:              []string{jeffID1_2, jeffID1_1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: jeffID1_2, id: 1}, DelegatorIDs{nodeID: jeffID1_1, id: 1}},
		})

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress2.String(),
			unlockedBalance:    "630000.00000000",
			lockedBalance:      "0.00000000",
			unlockedTokensUsed: "1000000.00000000",
			lockedTokensUsed:   "0.00000000",
			unlockLimit:        "370000.00000000",
			nodes:              []string{jeffID2_2, jeffID2_1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: jeffID2_2, id: 1}, DelegatorIDs{nodeID: jeffID2_1, id: 1}},
		})

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionTransferDelegator(env), jeffAddress1)
		_ = tx.AddArgument(cadence.NewString(jeffID1_2))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(cadence.NewAddress(jeffAddress2))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress1},
			[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner1},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress2.String(),
			unlockedBalance:    "630000.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "1500000.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "370000.0",
			nodes:              []string{jeffID2_2, jeffID2_1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: jeffID2_2, id: 1}, DelegatorIDs{nodeID: jeffID1_2, id: 1}, DelegatorIDs{nodeID: jeffID2_1, id: 1}},
		})
	})

	t.Run("Should fail because attempts to transfer node stored in locked account.", func(t *testing.T) {
		jeffAddress1, _, jeffSigner1, jeffID1_1, jeffID1_2 := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"0.0", "2000000.0")

		jeffAddress2, _, _, jeffID2_1, jeffID2_2 := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"0.0", "2000000.0")

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress1.String(),
			unlockedBalance:    "630000.00000000",
			lockedBalance:      "0.00000000",
			unlockedTokensUsed: "1000000.00000000",
			lockedTokensUsed:   "0.00000000",
			unlockLimit:        "370000.00000000",
			nodes:              []string{jeffID1_2, jeffID1_1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: jeffID1_2, id: 1}, DelegatorIDs{nodeID: jeffID1_1, id: 1}},
		})

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress2.String(),
			unlockedBalance:    "630000.00000000",
			lockedBalance:      "0.00000000",
			unlockedTokensUsed: "1000000.00000000",
			lockedTokensUsed:   "0.00000000",
			unlockLimit:        "370000.00000000",
			nodes:              []string{jeffID2_2, jeffID2_1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: jeffID2_2, id: 1}, DelegatorIDs{nodeID: jeffID2_1, id: 1}},
		})

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionTransferNode(env), jeffAddress1)
		_ = tx.AddArgument(cadence.NewString(jeffID1_1))
		_ = tx.AddArgument(cadence.NewAddress(jeffAddress2))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress1},
			[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner1},
			true,
		)
	})

	t.Run("Should fail because attempts to transfer delegator stored in locked account.", func(t *testing.T) {
		jeffAddress1, _, jeffSigner1, jeffID1_1, jeffID1_2 := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"0.0", "2000000.0")

		jeffAddress2, _, _, jeffID2_1, jeffID2_2 := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"0.0", "2000000.0")

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress1.String(),
			unlockedBalance:    "630000.00000000",
			lockedBalance:      "0.00000000",
			unlockedTokensUsed: "1000000.00000000",
			lockedTokensUsed:   "0.00000000",
			unlockLimit:        "370000.00000000",
			nodes:              []string{jeffID1_2, jeffID1_1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: jeffID1_2, id: 1}, DelegatorIDs{nodeID: jeffID1_1, id: 1}},
		})

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress2.String(),
			unlockedBalance:    "630000.00000000",
			lockedBalance:      "0.00000000",
			unlockedTokensUsed: "1000000.00000000",
			lockedTokensUsed:   "0.00000000",
			unlockLimit:        "370000.00000000",
			nodes:              []string{jeffID2_2, jeffID2_1},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: jeffID2_2, id: 1}, DelegatorIDs{nodeID: jeffID2_1, id: 1}},
		})

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionTransferDelegator(env), jeffAddress1)
		_ = tx.AddArgument(cadence.NewString(jeffID1_1))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(cadence.NewAddress(jeffAddress2))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress1},
			[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner1},
			true,
		)
	})

}
