package test

import (
	"fmt"
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/cadence/runtime/interpreter"
	ft_templates "github.com/onflow/flow-ft/lib/go/templates"
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

		// check balance of unlocked account
		result := executeScriptAndCheck(t, b, ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(regAccountAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		// check unlocked tokens used
		result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetUnlockedTokensUsedScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(regAccountAddress))})
		assertEqual(t, CadenceUFix64("1000000000.0"), result)

		// check locked tokens used
		result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetLockedTokensUsedScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(regAccountAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)
	})

	// Create a locked account pair with only tokens in the locked account
	joshAddress, joshSharedAddress, joshSigner := createLockedAccountPairWithBalances(
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

		// check balance of unlocked account
		result := executeScriptAndCheck(t, b, ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshSharedAddress))})
		assertEqual(t, CadenceUFix64("900.0"), result)

		// check unlocked tokens used
		result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetUnlockedTokensUsedScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		// check locked tokens used
		result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetLockedTokensUsedScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, CadenceUFix64("100.0"), result)
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

		// check balance of unlocked account
		result := executeScriptAndCheck(t, b, ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(maxAddress))})
		assertEqual(t, CadenceUFix64("900.0"), result)

		// check unlocked tokens used
		result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetUnlockedTokensUsedScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(maxAddress))})
		assertEqual(t, CadenceUFix64("100.0"), result)

		// check locked tokens used
		result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetLockedTokensUsedScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(maxAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)
	})

	// // Create a locked account pair with tokens in both accounts
	// jeffAddress, _, jeffSigner := createLockedAccountPairWithBalances(
	// 	t, b,
	// 	accountKeys,
	// 	env,
	// 	"1000.0", "1000.0")

	// // add a staking collection to the main account
	// tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), jeffAddress)

	// signAndSubmit(
	// 	t, b, tx,
	// 	[]flow.Address{b.ServiceKey().Address, jeffAddress},
	// 	[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner},
	// 	false,
	// )

	// t.Run("should be able to get tokens with sufficient balance in both accounts", func(t *testing.T) {
	// 	// Should fail because there is enough in locked account, but not enough in unlocked account
	// 	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionGetTokensScript(env), jeffAddress)
	// 	_ = tx.AddArgument(CadenceUFix64("1000000.0"))

	// 	signAndSubmit(
	// 		t, b, tx,
	// 		[]flow.Address{b.ServiceKey().Address, jeffAddress},
	// 		[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner},
	// 		false,
	// 	)

	// 	// Should succeed because there is enough sum in both accounts, should increase both used numbers
	// 	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionGetTokensScript(env), jeffAddress)
	// 	_ = tx.AddArgument(CadenceUFix64("1500.0"))

	// 	signAndSubmit(
	// 		t, b, tx,
	// 		[]flow.Address{b.ServiceKey().Address, jeffAddress},
	// 		[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner},
	// 		false,
	// 	)
	// })
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

	// Create a locked account pair with only tokens in the locked account
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
			nodes:              []string{maxID, joshID},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: maxID, id: 1}, DelegatorIDs{nodeID: joshID, id: 1}},
		})
	})
}
