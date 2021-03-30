package test

import (
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	ft_templates "github.com/onflow/flow-ft/lib/go/templates"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"

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

		// check balance of unlocked account
		result := executeScriptAndCheck(t, b, ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(regAccountAddress))})
		assertEqual(t, CadenceUFix64("1000000000.0"), result)

		// check unlocked tokens used
		result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetUnlockedTokensUsedScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(regAccountAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		// check unlocked tokens used
		result = executeScriptAndCheck(t, b, templates.GenerateCollectionGetLockedTokensUsedScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(regAccountAddress))})
		assertEqual(t, CadenceUFix64("0.0"), result)
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

	t.Run("", func(t *testing.T) {

	})

}

func TestStakingCollectionRegisterNode(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)
	_ = deployAllCollectionContracts(t, b, accountKeys, &env)

	// Create regular accounts
	//userAddresses, userAccountKeys, userSigners := registerAndMintManyAccounts(t, b, accountKeys, 4)

	// and register a normal node

	// setup the staking collection which should put the normal node in the collection

	// Create a regular account and register a delegator

	// setup the staking collection which should put the normal delegator in the collection

	// Create a locked account pair with only tokens in the locked account
	joshAddress, _, joshSigner := createLockedAccountPairWithBalances(
		t, b,
		accountKeys,
		env,
		"1000.0", "1000.0")

	// Register a node and a delegator in the locked account

	// add a staking collection to the main account
	// the node and delegator in the locked account should be accesible through the staking collection
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), joshAddress)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, joshAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
		false,
	)

	t.Run("Should be able to register a node with the staking collection", func(t *testing.T) {

	})
}

func TestStakingCollectionDoesStakeExist(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)
	_ = deployAllCollectionContracts(t, b, accountKeys, &env)

	t.Run("", func(t *testing.T) {

	})
}
