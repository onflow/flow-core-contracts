package test

import (
	"encoding/hex"
	"fmt"
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/cadence/runtime/interpreter"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

func TestStakingCollectionDeploy(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)

	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

	deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)
}

func TestStakingCollectionGetTokens(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)
	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

	deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

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
		"1000000000.0",
		"1000.0", "0.0",
		adminAccountKey, adminAddress, adminSigner)

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
		"1000000000.0",
		"0.0", "1000.0",
		adminAccountKey, adminAddress, adminSigner)

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
		"1000000000.0",
		"1000.0", "1000.0",
		adminAccountKey, adminAddress, adminSigner)

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
	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

	deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

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
		"1000000000.0",
		"1000.0", "0.0",
		adminAccountKey, adminAddress, adminSigner)

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
		"1000000000.0",
		"1000.0", "1000.0",
		adminAccountKey, adminAddress, adminSigner)

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
	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

	deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

	// Create regular accounts
	userAddresses, _, userSigners := registerAndMintManyAccounts(t, b, accountKeys, 4)
	_, adminStakingKey, _, adminNetworkingKey := generateKeysForNodeRegistration(t)

	var amountToCommit interpreter.UFix64Value = 48000000000000

	// and register a normal node outside of the collection
	registerNode(t, b, env,
		userAddresses[0],
		userSigners[0],
		adminID,
		fmt.Sprintf("%0128d", admin),
		adminNetworkingKey,
		adminStakingKey,
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
	err := tx.AddArgument(cadence.NewArray([]cadence.Value{CadenceString(adminID), CadenceString(joshID)}))
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
		"1000000000.0",
		"1000000.0", "1000000.0",
		adminAccountKey, adminAddress, adminSigner)
	_, joshStakingKey, _, joshNetworkingKey := generateKeysForNodeRegistration(t)

	// Register a node and a delegator in the locked account
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterLockedNodeScript(env), joshAddress)
	_ = tx.AddArgument(CadenceString(joshID))
	_ = tx.AddArgument(cadence.NewUInt8(4))
	_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", josh)))
	_ = tx.AddArgument(CadenceString(joshNetworkingKey))
	_ = tx.AddArgument(CadenceString(joshStakingKey))
	_ = tx.AddArgument(CadenceUFix64("320000.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, joshAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
		false,
	)

	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateLockedDelegatorScript(env), joshAddress)
	_ = tx.AddArgument(CadenceString(joshID))
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

	machineAccounts := make(map[cadence.String]flow.Address)

	t.Run("Should not be able to register a consensus node without a machine account public key", func(t *testing.T) {

		_, maxStakingKey, _, maxNetworkingKey := generateKeysForNodeRegistration(t)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterNode(env), joshAddress)
		_ = tx.AddArgument(CadenceString(maxID))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", max)))
		_ = tx.AddArgument(CadenceString(maxNetworkingKey))
		_ = tx.AddArgument(CadenceString(maxStakingKey))
		_ = tx.AddArgument(CadenceUFix64("500000.0"))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)
	})

	publicKeys := make([]cadence.Value, 1)
	machineAccountKey, _ := accountKeys.NewWithSigner()
	machineAccountKeyString := hex.EncodeToString(machineAccountKey.Encode())
	publicKeys[0] = CadenceString(machineAccountKeyString)
	cadencePublicKeys := cadence.NewArray(publicKeys)

	t.Run("Should be able to register a second node and delegator in the staking collection", func(t *testing.T) {

		_, maxStakingKey, _, maxNetworkingKey := generateKeysForNodeRegistration(t)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterNode(env), joshAddress)
		_ = tx.AddArgument(CadenceString(maxID))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", max)))
		_ = tx.AddArgument(CadenceString(maxNetworkingKey))
		_ = tx.AddArgument(CadenceString(maxStakingKey))
		_ = tx.AddArgument(CadenceUFix64("500000.0"))
		_ = tx.AddArgument(cadence.NewOptional(cadencePublicKeys))

		result := signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		machineAccounts[CadenceString(maxID).(cadence.String)] = getMachineAccountFromEvent(t, b, env, result)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterDelegator(env), joshAddress)
		_ = tx.AddArgument(CadenceString(maxID))
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
			machineAccounts:    machineAccounts,
		})
	})

	t.Run("Should be able to register a collection node in the staking collection and create a machine account", func(t *testing.T) {

		_, bastianStakingKey, _, bastianNetworkingKey := generateKeysForNodeRegistration(t)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterNode(env), joshAddress)
		_ = tx.AddArgument(CadenceString(bastianID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", bastian)))
		_ = tx.AddArgument(CadenceString(bastianNetworkingKey))
		_ = tx.AddArgument(CadenceString(bastianStakingKey))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))
		_ = tx.AddArgument(cadence.NewOptional(cadencePublicKeys))

		result := signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		machineAccounts[CadenceString(bastianID).(cadence.String)] = getMachineAccountFromEvent(t, b, env, result)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "620000.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "380000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "0.0",
			nodes:              []string{maxID, bastianID, joshID},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: maxID, id: 1}, DelegatorIDs{nodeID: joshID, id: 1}},
			machineAccounts:    machineAccounts,
		})
	})

	t.Run("Should be able to deposit and withdraw tokens from the machine account", func(t *testing.T) {

		// Add 100 tokens to the machine account
		mintTokensForAccount(t, b, machineAccounts[CadenceString(bastianID).(cadence.String)], "100.0")

		// Should fail because this node does not exist in the collection
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionWithdrawFromMachineAccountScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(executionID))
		_ = tx.AddArgument(CadenceUFix64("50.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionWithdrawFromMachineAccountScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(bastianID))
		_ = tx.AddArgument(CadenceUFix64("50.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "620050.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "380000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "0.0",
			nodes:              []string{maxID, bastianID, joshID},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: maxID, id: 1}, DelegatorIDs{nodeID: joshID, id: 1}},
			machineAccounts:    machineAccounts,
		})
	})

	t.Run("Should be able to register a execution and verification node in the staking collection and not create machine accounts", func(t *testing.T) {

		_, executionStakingKey, _, executionNetworkingKey := generateKeysForNodeRegistration(t)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterNode(env), joshAddress)
		_ = tx.AddArgument(CadenceString(executionID))
		_ = tx.AddArgument(cadence.NewUInt8(3))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", execution)))
		_ = tx.AddArgument(CadenceString(executionNetworkingKey))
		_ = tx.AddArgument(CadenceString(executionStakingKey))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Should fail because the execution node does not have a machine account
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionWithdrawFromMachineAccountScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(executionID))
		_ = tx.AddArgument(CadenceUFix64("50.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		_, verificationStakingKey, _, verificationNetworkingKey := generateKeysForNodeRegistration(t)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterNode(env), joshAddress)
		_ = tx.AddArgument(CadenceString(verificationID))
		_ = tx.AddArgument(cadence.NewUInt8(3))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", verification)))
		_ = tx.AddArgument(CadenceString(verificationNetworkingKey))
		_ = tx.AddArgument(CadenceString(verificationStakingKey))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "600050.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "400000.0",
			lockedTokensUsed:   "630000.0",
			unlockLimit:        "0.0",
			nodes:              []string{maxID, bastianID, executionID, verificationID, joshID},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: maxID, id: 1}, DelegatorIDs{nodeID: joshID, id: 1}},
			machineAccounts:    machineAccounts,
		})
	})

	t.Run("Should be able to update the networking address for the execution node", func(t *testing.T) {

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionUpdateNetworkingAddressScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(executionID))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", newAddress)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNetworkingAddressScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(executionID))})
		assertEqual(t, CadenceString(fmt.Sprintf("%0128d", newAddress)), result)
	})
}

func TestStakingCollectionCreateMachineAccountForExistingNode(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)
	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

	deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

	// Create regular accounts
	userAddresses, _, userSigners := registerAndMintManyAccounts(t, b, accountKeys, 4)
	_, adminStakingKey, _, adminNetworkingKey := generateKeysForNodeRegistration(t)

	var amountToCommit interpreter.UFix64Value = 48000000000000

	// and register a normal node outside of the collection
	registerNode(t, b, env,
		userAddresses[0],
		userSigners[0],
		adminID,
		fmt.Sprintf("%0128d", admin),
		adminNetworkingKey,
		adminStakingKey,
		amountToCommit,
		amountToCommit,
		1,
		false)

	// end staking auction and epoch, then pay rewards
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), flow.HexToAddress(env.IDTableAddress))
	err := tx.AddArgument(cadence.NewArray([]cadence.Value{CadenceString(adminID), CadenceString(joshID)}))
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

	publicKeys := make([]cadence.Value, 1)
	machineAccountKey, _ := accountKeys.NewWithSigner()
	machineAccountKeyString := hex.EncodeToString(machineAccountKey.Encode())
	publicKeys[0] = CadenceString(machineAccountKeyString)
	cadencePublicKeys := cadence.NewArray(publicKeys)

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
			delegators:         []DelegatorIDs{},
		})

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCreateMachineAccountForNodeScript(env), userAddresses[0])
		_ = tx.AddArgument(CadenceString(adminID))
		_ = tx.AddArgument(cadencePublicKeys)

		result := signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, userAddresses[0]},
			[]crypto.Signer{b.ServiceKey().Signer(), userSigners[0]},
			false,
		)

		machineAccounts := make(map[cadence.String]flow.Address)
		machineAccounts[CadenceString(adminID).(cadence.String)] = getMachineAccountFromEvent(t, b, env, result)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     userAddresses[0].String(),
			unlockedBalance:    "999520000.0",
			lockedBalance:      "",
			unlockedTokensUsed: "480000.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "",
			nodes:              []string{adminID},
			delegators:         []DelegatorIDs{},
			machineAccounts:    machineAccounts,
		})

	})

	// Create a locked account pair with tokens in both accounts
	joshAddress, _, joshSigner := createLockedAccountPairWithBalances(
		t, b,
		accountKeys,
		env,
		"1000000000.0",
		"1000000.0", "1000000.0",
		adminAccountKey, adminAddress, adminSigner)

	_, joshStakingKey, _, joshNetworkingKey := generateKeysForNodeRegistration(t)

	// Register a node and a delegator in the locked account
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterLockedNodeScript(env), joshAddress)
	_ = tx.AddArgument(CadenceString(joshID))
	_ = tx.AddArgument(cadence.NewUInt8(2))
	_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", josh)))
	_ = tx.AddArgument(CadenceString(joshNetworkingKey))
	_ = tx.AddArgument(CadenceString(joshStakingKey))
	_ = tx.AddArgument(CadenceUFix64("320000.0"))

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
			lockedBalance:      "680000.0",
			unlockedTokensUsed: "0.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "0.0",
			nodes:              []string{joshID},
			delegators:         []DelegatorIDs{},
		})

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCreateMachineAccountForNodeScript(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID))
		_ = tx.AddArgument(cadencePublicKeys)

		result := signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		machineAccounts := make(map[cadence.String]flow.Address)
		machineAccounts[CadenceString(joshID).(cadence.String)] = getMachineAccountFromEvent(t, b, env, result)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     joshAddress.String(),
			unlockedBalance:    "1000000.0",
			lockedBalance:      "680000.0",
			unlockedTokensUsed: "0.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "0.0",
			nodes:              []string{joshID},
			delegators:         []DelegatorIDs{},
			machineAccounts:    machineAccounts,
		})

	})

}

func TestStakingCollectionStakeTokens(t *testing.T) {
	b, accountKeys, env := newTestSetup(t)
	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

	deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

	joshAddress, _, joshSigner, joshID1, joshID2 := registerStakingCollectionNodesAndDelegators(
		t, b,
		accountKeys,
		env,
		"1000000.0", "1000000.0",
		adminAccountKey, adminAddress, adminSigner)

	t.Run("Should be able to commit new tokens to the node or delegator in both accounts", func(t *testing.T) {

		// Should fail because stake doesn't exist
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeNewTokens(env), joshAddress)
		_ = tx.AddArgument(CadenceString(accessID))
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
		_ = tx.AddArgument(CadenceString(joshID1))
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
		_ = tx.AddArgument(CadenceString(joshID2))
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
		_ = tx.AddArgument(CadenceString(joshID1))
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
		_ = tx.AddArgument(CadenceString(joshID2))
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
		_ = tx.AddArgument(CadenceString(accessID))
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
		_ = tx.AddArgument(CadenceString(joshID1))
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
		_ = tx.AddArgument(CadenceString(joshID2))
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
		_ = tx.AddArgument(CadenceString(joshID1))
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
		_ = tx.AddArgument(CadenceString(joshID2))
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
		_ = tx.AddArgument(CadenceString(accessID))
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
		_ = tx.AddArgument(CadenceString(joshID1))
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
		_ = tx.AddArgument(CadenceString(joshID2))
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
		_ = tx.AddArgument(CadenceString(joshID1))
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
		_ = tx.AddArgument(CadenceString(joshID2))
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
		_ = tx.AddArgument(CadenceString(accessID))
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
		_ = tx.AddArgument(CadenceString(joshID1))
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
		_ = tx.AddArgument(CadenceString(joshID2))
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
		_ = tx.AddArgument(CadenceString(joshID1))
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
		_ = tx.AddArgument(CadenceString(joshID2))
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
	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

	deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

	joshAddress, _, joshSigner, joshID1, joshID2 := registerStakingCollectionNodesAndDelegators(
		t, b,
		accountKeys,
		env,
		"1000000.0", "1000000.0",
		adminAccountKey, adminAddress, adminSigner)

	// end staking auction and epoch, then pay rewards
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), flow.HexToAddress(env.IDTableAddress))
	err := tx.AddArgument(cadence.NewArray([]cadence.Value{CadenceString(adminID), CadenceString(joshID)}))
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
		_ = tx.AddArgument(CadenceString(accessID))
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
		_ = tx.AddArgument(CadenceString(joshID1))
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
		_ = tx.AddArgument(CadenceString(joshID2))
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
		_ = tx.AddArgument(CadenceString(joshID1))
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
		_ = tx.AddArgument(CadenceString(joshID2))
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
		_ = tx.AddArgument(CadenceString(accessID))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// withdraw rewarded tokens to the locked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// withdraw rewarded tokens to the unlocked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// withdraw rewarded tokens to the locked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID1))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(CadenceUFix64("5000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// withdraw rewarded tokens to the unlocked account delegator
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionStakeRewardedTokens(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID2))
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
		_ = tx.AddArgument(CadenceString(accessID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// unstake all tokens to the locked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionUnstakeAll(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID1))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// unstake all tokens to the unlocked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionUnstakeAll(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID2))

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

	t.Run("Should be able to stake rewards from all the nodes and delegators an account owns", func(t *testing.T) {

		// withdraw rewarded tokens to the locked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRestakeAllStakersTokens(env), joshAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)
	})

}

func TestStakingCollectionCloseStake(t *testing.T) {

	b, accountKeys, env := newTestSetup(t)
	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

	deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

	joshAddress, _, joshSigner, joshID1, joshID2 := registerStakingCollectionNodesAndDelegators(
		t, b,
		accountKeys,
		env,
		"1000000.0", "1000000.0",
		adminAccountKey, adminAddress, adminSigner)

	t.Run("Should fail to close a stake and delegation stored in the locked account if there are tokens in a 'staked' state", func(t *testing.T) {

		// Should fail because node isn't ready to be closed. tokens in committed bucket
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// Should fail because node isn't ready to be closed.
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// End staking auction and epoch
		endStakingMoveTokens(t, b, env, flow.HexToAddress(env.IDTableAddress), IDTableSigner,
			[]cadence.Value{CadenceString(adminID), CadenceString(joshID)},
		)

		// Should fail because node isn't ready to be closed. tokens in staked bucket
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// Should fail because node isn't ready to be closed. tokens in staked
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID2))
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
		_ = tx.AddArgument(CadenceString(joshID1))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// Request Unstaking all delegated tokens to joshID1
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRequestUnstaking(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID1))
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
		_ = tx.AddArgument(CadenceString(joshID2))
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
		_ = tx.AddArgument(CadenceString(joshID2))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		// End staking auction and epoch
		endStakingMoveTokens(t, b, env, flow.HexToAddress(env.IDTableAddress), IDTableSigner,
			[]cadence.Value{CadenceString(adminID), CadenceString(joshID)},
		)

		// Should fail because node isn't ready to be closed. tokens in unstaking bucket
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID1))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		// Should fail because node isn't ready to be closed. tokens in unstaking
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(cadence.NewUInt32(1)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		endStakingMoveTokens(t, b, env, flow.HexToAddress(env.IDTableAddress), IDTableSigner,
			[]cadence.Value{CadenceString(adminID), CadenceString(joshID)},
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
		_ = tx.AddArgument(CadenceString(joshID1))
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
		_ = tx.AddArgument(CadenceString(joshID1))
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
		_ = tx.AddArgument(CadenceString(joshID2))
		_ = tx.AddArgument(cadence.NewOptional(nil))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCloseStake(env), joshAddress)
		_ = tx.AddArgument(CadenceString(joshID2))
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
	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

	deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

	t.Run("Should fail because account was not created with staking collection", func(t *testing.T) {
		joshAddress, _, _ := createLockedAccountPairWithBalances(
			t, b,
			accountKeys,
			env,
			"1000000000.0",
			"1000000.0", "1000000.0",
			adminAccountKey, adminAddress, adminSigner)

		result := executeScriptAndCheck(t, b, templates.GenerateCollectionDoesAccountHaveStakingCollection(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, cadence.NewBool(false), result)
	})

	t.Run("Should fail because account was not created with staking collection", func(t *testing.T) {
		joshAddress, _, _, _, _ := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"1000000.0", "1000000.0",
			adminAccountKey, adminAddress, adminSigner)

		result := executeScriptAndCheck(t, b, templates.GenerateCollectionDoesAccountHaveStakingCollection(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		assertEqual(t, cadence.NewBool(true), result)
	})
}

func TestStakingCollectionRemoveNodeStaker(t *testing.T) {

	t.Run("Should fail to transfer a node staker because account uses locked tokens", func(t *testing.T) {
		b, accountKeys, env := newTestSetup(t)
		// Create new keys for the epoch account
		idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

		_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
			startEpochCounter, // start epoch counter
			numEpochViews,     // num views per epoch
			numStakingViews,   // num views for staking auction
			numDKGViews,       // num views for DKG phase
			numClusters,       // num collector clusters
			randomSource,      // random source
			rewardIncreaseFactor)

		adminAccountKey, adminSigner := accountKeys.NewWithSigner()
		adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

		deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

		jeffAddress1, _, jeffSigner1, jeffID1_1, _ := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"1000000.0", "1000000.0",
			adminAccountKey, adminAddress, adminSigner)

		// Create a locked account pair with tokens in both accounts
		jeffAddress2, _, jeff2Signer := createLockedAccountPairWithBalances(
			t, b,
			accountKeys,
			env,
			"1000000000.0",
			"1000000.0", "1000000.0",
			adminAccountKey, adminAddress, adminSigner)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), jeffAddress2)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress2},
			[]crypto.Signer{b.ServiceKey().Signer(), jeff2Signer},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionTransferNode(env), jeffAddress1)
		_ = tx.AddArgument(CadenceString(jeffID1_1))
		_ = tx.AddArgument(cadence.NewAddress(jeffAddress2))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress1},
			[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner1},
			true,
		)
	})

	t.Run("Should fail to transfer a node delegator because account uses locked tokens", func(t *testing.T) {
		b, accountKeys, env := newTestSetup(t)
		// Create new keys for the epoch account
		idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

		_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
			startEpochCounter, // start epoch counter
			numEpochViews,     // num views per epoch
			numStakingViews,   // num views for staking auction
			numDKGViews,       // num views for DKG phase
			numClusters,       // num collector clusters
			randomSource,      // random source
			rewardIncreaseFactor)

		adminAccountKey, adminSigner := accountKeys.NewWithSigner()
		adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

		deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

		jeffAddress1, _, jeffSigner1, jeffID1_1, _ := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"1000000.0", "1000000.0",
			adminAccountKey, adminAddress, adminSigner)

		// Create a locked account pair with tokens in both accounts
		jeffAddress2, _, jeff2Signer := createLockedAccountPairWithBalances(
			t, b,
			accountKeys,
			env,
			"1000000000.0",
			"1000000.0", "1000000.0",
			adminAccountKey, adminAddress, adminSigner)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), jeffAddress2)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress2},
			[]crypto.Signer{b.ServiceKey().Signer(), jeff2Signer},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionTransferDelegator(env), jeffAddress1)
		_ = tx.AddArgument(CadenceString(jeffID1_1))
		_ = tx.AddArgument(cadence.NewUInt32(1))
		_ = tx.AddArgument(cadence.NewAddress(jeffAddress2))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress1},
			[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner1},
			true,
		)
	})

	t.Run("Should be able to transfer a node staker stored in Staking Collection between accounts.", func(t *testing.T) {
		b, accountKeys, env := newTestSetup(t)
		// Create new keys for the epoch account
		idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

		_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
			startEpochCounter, // start epoch counter
			numEpochViews,     // num views per epoch
			numStakingViews,   // num views for staking auction
			numDKGViews,       // num views for DKG phase
			numClusters,       // num collector clusters
			randomSource,      // random source
			rewardIncreaseFactor)

		adminAccountKey, adminSigner := accountKeys.NewWithSigner()
		adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

		deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

		jeffAddress1, _, jeffSigner1, jeffID1_1, jeffID1_2 := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"0.0", "2000000.0",
			adminAccountKey, adminAddress, adminSigner)

		// Create a locked account pair with tokens in both accounts
		jeffAddress2, _, jeff2Signer := createLockedAccountPairWithBalances(
			t, b,
			accountKeys,
			env,
			"1000000000.0",
			"0.0", "2000000.0",
			adminAccountKey, adminAddress, adminSigner)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), jeffAddress2)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress2},
			[]crypto.Signer{b.ServiceKey().Signer(), jeff2Signer},
			false,
		)

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
			unlockedBalance:    "2000000.00000000",
			lockedBalance:      "0.00000000",
			unlockedTokensUsed: "0.00000000",
			lockedTokensUsed:   "0.00000000",
			unlockLimit:        "0.00000000",
			nodes:              []string{},
			delegators:         []DelegatorIDs{},
		})

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionTransferNode(env), jeffAddress1)
		_ = tx.AddArgument(CadenceString(jeffID1_2))
		_ = tx.AddArgument(cadence.NewAddress(jeffAddress2))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress1},
			[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner1},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress2.String(),
			unlockedBalance:    "2000000.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "500000.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "0.0",
			nodes:              []string{jeffID1_2},
			delegators:         []DelegatorIDs{},
		})
	})

	t.Run("Should be able to transfer a delegator stored in Staking Collection between accounts.", func(t *testing.T) {
		b, accountKeys, env := newTestSetup(t)
		// Create new keys for the epoch account
		idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

		_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
			startEpochCounter, // start epoch counter
			numEpochViews,     // num views per epoch
			numStakingViews,   // num views for staking auction
			numDKGViews,       // num views for DKG phase
			numClusters,       // num collector clusters
			randomSource,      // random source
			rewardIncreaseFactor)

		adminAccountKey, adminSigner := accountKeys.NewWithSigner()
		adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

		deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

		jeffAddress1, _, jeffSigner1, jeffID1_1, jeffID1_2 := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"0.0", "2000000.0",
			adminAccountKey, adminAddress, adminSigner)

		// Create a locked account pair with tokens in both accounts
		jeffAddress2, _, jeff2Signer := createLockedAccountPairWithBalances(
			t, b,
			accountKeys,
			env,
			"1000000000.0",
			"0.0", "2000000.0",
			adminAccountKey, adminAddress, adminSigner)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), jeffAddress2)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress2},
			[]crypto.Signer{b.ServiceKey().Signer(), jeff2Signer},
			false,
		)

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
			unlockedBalance:    "2000000.00000000",
			lockedBalance:      "0.00000000",
			unlockedTokensUsed: "0.00000000",
			lockedTokensUsed:   "0.00000000",
			unlockLimit:        "0.00000000",
			nodes:              []string{},
			delegators:         []DelegatorIDs{},
		})

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionTransferDelegator(env), jeffAddress1)
		_ = tx.AddArgument(CadenceString(jeffID1_2))
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
			unlockedBalance:    "2000000.0",
			lockedBalance:      "0.0",
			unlockedTokensUsed: "500000.0",
			lockedTokensUsed:   "0.0",
			unlockLimit:        "0.0",
			nodes:              []string{},
			delegators:         []DelegatorIDs{DelegatorIDs{nodeID: jeffID1_2, id: 1}},
		})
	})

	t.Run("Should fail because attempts to transfer node stored in locked account.", func(t *testing.T) {
		b, accountKeys, env := newTestSetup(t)
		// Create new keys for the epoch account
		idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

		_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
			startEpochCounter, // start epoch counter
			numEpochViews,     // num views per epoch
			numStakingViews,   // num views for staking auction
			numDKGViews,       // num views for DKG phase
			numClusters,       // num collector clusters
			randomSource,      // random source
			rewardIncreaseFactor)

		adminAccountKey, adminSigner := accountKeys.NewWithSigner()
		adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

		deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

		jeffAddress1, _, jeffSigner1, jeffID1_1, jeffID1_2 := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"0.0", "2000000.0",
			adminAccountKey, adminAddress, adminSigner)

		// Create a locked account pair with tokens in both accounts
		jeffAddress2, _, jeff2Signer := createLockedAccountPairWithBalances(
			t, b,
			accountKeys,
			env,
			"1000000000.0",
			"0.0", "2000000.0",
			adminAccountKey, adminAddress, adminSigner)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), jeffAddress2)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress2},
			[]crypto.Signer{b.ServiceKey().Signer(), jeff2Signer},
			false,
		)

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

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionTransferNode(env), jeffAddress1)
		_ = tx.AddArgument(CadenceString(jeffID1_1))
		_ = tx.AddArgument(cadence.NewAddress(jeffAddress2))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress1},
			[]crypto.Signer{b.ServiceKey().Signer(), jeffSigner1},
			true,
		)
	})

	t.Run("Should fail because attempts to transfer delegator stored in locked account.", func(t *testing.T) {
		b, accountKeys, env := newTestSetup(t)
		// Create new keys for the epoch account
		idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

		_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
			startEpochCounter, // start epoch counter
			numEpochViews,     // num views per epoch
			numStakingViews,   // num views for staking auction
			numDKGViews,       // num views for DKG phase
			numClusters,       // num collector clusters
			randomSource,      // random source
			rewardIncreaseFactor)

		adminAccountKey, adminSigner := accountKeys.NewWithSigner()
		adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

		deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

		jeffAddress1, _, jeffSigner1, jeffID1_1, jeffID1_2 := registerStakingCollectionNodesAndDelegators(
			t, b,
			accountKeys,
			env,
			"0.0", "2000000.0",
			adminAccountKey, adminAddress, adminSigner)

		// Create a locked account pair with tokens in both accounts
		jeffAddress2, _, jeff2Signer := createLockedAccountPairWithBalances(
			t, b,
			accountKeys,
			env,
			"1000000000.0",
			"0.0", "2000000.0",
			adminAccountKey, adminAddress, adminSigner)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), jeffAddress2)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress2},
			[]crypto.Signer{b.ServiceKey().Signer(), jeff2Signer},
			false,
		)

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

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionTransferDelegator(env), jeffAddress1)
		_ = tx.AddArgument(CadenceString(jeffID1_1))
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

func TestStakingCollectionCreateNewTokenHolder(t *testing.T) {

	t.Run("Should be able to create a new token holder object with a new account and staking collection", func(t *testing.T) {
		b, accountKeys, env := newTestSetup(t)
		// Create new keys for the epoch account
		idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

		_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
			startEpochCounter, // start epoch counter
			numEpochViews,     // num views per epoch
			numStakingViews,   // num views for staking auction
			numDKGViews,       // num views for DKG phase
			numClusters,       // num collector clusters
			randomSource,      // random source
			rewardIncreaseFactor)

		adminAccountKey, adminSigner := accountKeys.NewWithSigner()
		adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

		deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

		jeffAddress2, lockedAddress, jeff2Signer := createLockedAccountPairWithBalances(
			t, b,
			accountKeys,
			env,
			"1000000000.0",
			"400000.0", "1.0",
			adminAccountKey, adminAddress, adminSigner)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterLockedNodeScript(env), jeffAddress2)

		userNodeID1 := "0000000000000000000000000000000000000000000000000000000000000001"
		_, nodeOneStakingKey, _, nodeOneNetworkingKey := generateKeysForNodeRegistration(t)

		_ = tx.AddArgument(CadenceString(userNodeID1))
		_ = tx.AddArgument(cadence.NewUInt8(4))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", 1)))
		_ = tx.AddArgument(CadenceString(nodeOneNetworkingKey))
		_ = tx.AddArgument(CadenceString(nodeOneStakingKey))
		_ = tx.AddArgument(CadenceUFix64("320000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress2},
			[]crypto.Signer{b.ServiceKey().Signer(), jeff2Signer},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionCreateNewTokenHolderAccountScript(env), lockedAddress)

		publicKeys := make([]cadence.Value, 1)
		newAccountKey, newAccountSigner := accountKeys.NewWithSigner()
		newAccountKeyString := hex.EncodeToString(newAccountKey.Encode())
		publicKeys[0] = CadenceString(newAccountKeyString)
		cadencePublicKeys := cadence.NewArray(publicKeys)
		_ = tx.AddArgument(cadencePublicKeys)

		// Sign and submit the transaction
		err := tx.SignPayload(lockedAddress, 0, adminSigner)
		assert.NoError(t, err)
		err = tx.SignEnvelope(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().Signer())
		require.NoError(t, err)
		err = b.AddTransaction(*tx)
		require.NoError(t, err)
		result, err := b.ExecuteNextTransaction()
		require.NoError(t, err)
		require.NoError(t, result.Error)

		// Search emitted events from the transaction result
		// to find the address of the locked tokens contract
		var newAccountAddr flow.Address

		for _, event := range result.Events {
			if event.Type == flow.EventAccountCreated {
				accountCreatedEvent := flow.AccountCreatedEvent(event)
				newAccountAddr = accountCreatedEvent.Address()
				break
			}
		}

		// Commit the result as a block
		_, err = b.CommitBlock()
		require.NoError(t, err)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     newAccountAddr.String(),
			unlockedBalance:    "0.000000",
			lockedBalance:      "80000.00000000",
			unlockedTokensUsed: "0.00000000",
			lockedTokensUsed:   "0.00000000",
			unlockLimit:        "0.00000000",
			nodes:              []string{userNodeID1},
			delegators:         []DelegatorIDs{},
		})

		// unstake tokens from the locked account node
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRequestUnstaking(env), newAccountAddr)
		_ = tx.AddArgument(CadenceString(userNodeID1))
		_ = tx.AddArgument(cadence.NewOptional(nil))
		_ = tx.AddArgument(CadenceUFix64("10000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, newAccountAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), newAccountSigner},
			false,
		)
	})
}

func TestStakingCollectionRegisterMultipleNodes(t *testing.T) {

	b, accountKeys, env := newTestSetup(t)
	// Create new keys for the epoch account
	idTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()

	_, _ = initializeAllEpochContracts(t, b, idTableAccountKey, IDTableSigner, &env,
		startEpochCounter, // start epoch counter
		numEpochViews,     // num views per epoch
		numStakingViews,   // num views for staking auction
		numDKGViews,       // num views for DKG phase
		numClusters,       // num collector clusters
		randomSource,      // random source
		rewardIncreaseFactor)

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := b.CreateAccount([]*flow.AccountKey{adminAccountKey}, nil)

	deployAllCollectionContracts(t, b, accountKeys, &env, adminAddress, adminSigner)

	jeffAddress2, _, jeff2Signer := createLockedAccountPairWithBalances(
		t, b,
		accountKeys,
		env,
		"1000000000.0",
		"0.0", "100000000.0",
		adminAccountKey, adminAddress, adminSigner)

	// Setup the staking collection
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), jeffAddress2)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, jeffAddress2},
		[]crypto.Signer{b.ServiceKey().Signer(), jeff2Signer},
		false,
	)

	numNodes := 10

	// Create arrays for the node account information
	nodeStakingKeys := make([]cadence.Value, numNodes)
	nodeNetworkingKeys := make([]cadence.Value, numNodes)
	nodeNetworkingAddresses := make([]cadence.Value, numNodes)
	ids, _, _ := generateNodeIDs(numNodes)
	roles := make([]int, numNodes)
	machineAccountKeys := make([]cadence.Value, numNodes)

	cadenceIDs := make([]cadence.Value, numNodes)
	cadenceRoles := make([]cadence.Value, numNodes)
	cadenceAmounts := make([]cadence.Value, numNodes)

	// Create all the node accounts
	for i := 0; i < numNodes; i++ {
		_, stakingKey, _, networkingKey := generateKeysForNodeRegistration(t)

		nodeStakingKeys[i] = CadenceString(stakingKey)
		nodeNetworkingKeys[i] = CadenceString(networkingKey)

		nodeNetworkingAddresses[i] = CadenceString(fmt.Sprintf("%0128s", ids[i]))

		cadenceIDs[i] = CadenceString(ids[i])

		cadenceAmounts[i] = CadenceUFix64("2000000.0")

		roles[i] = i%4 + 1
		cadenceRoles[i] = cadence.NewUInt8(uint8(roles[i]))

		if i%4+1 == 1 || i%4+1 == 2 {
			publicKeys := make([]cadence.Value, 1)
			machineAccountKey, _ := accountKeys.NewWithSigner()
			machineAccountKeyString := hex.EncodeToString(machineAccountKey.Encode())
			publicKeys[0] = CadenceString(machineAccountKeyString)
			machineAccountKeys[i] = cadence.NewOptional(cadence.NewArray(publicKeys))
		} else {
			machineAccountKeys[i] = cadence.NewOptional(nil)
		}

	}

	t.Run("Should be able to register multiple nodes with the staking collection", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterMultipleNodesScript(env), jeffAddress2)
		_ = tx.AddArgument(cadence.NewArray(cadenceIDs))
		_ = tx.AddArgument(cadence.NewArray(cadenceRoles))
		_ = tx.AddArgument(cadence.NewArray(nodeNetworkingAddresses))
		_ = tx.AddArgument(cadence.NewArray(nodeNetworkingKeys))
		_ = tx.AddArgument(cadence.NewArray(nodeStakingKeys))
		_ = tx.AddArgument(cadence.NewArray(cadenceAmounts))
		_ = tx.AddArgument(cadence.NewArray(machineAccountKeys))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress2},
			[]crypto.Signer{b.ServiceKey().Signer(), jeff2Signer},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress2.String(),
			unlockedBalance:    "80000000.000000",
			lockedBalance:      "0.00000000",
			unlockedTokensUsed: "20000000.00000000",
			lockedTokensUsed:   "0.00000000",
			unlockLimit:        "0.00000000",
			nodes:              ids,
			delegators:         []DelegatorIDs{},
		})

	})

	t.Run("Should be able to register multiple delegators with the staking collection", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterMultipleDelegatorsScript(env), jeffAddress2)
		_ = tx.AddArgument(cadence.NewArray(cadenceIDs))
		_ = tx.AddArgument(cadence.NewArray(cadenceAmounts))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jeffAddress2},
			[]crypto.Signer{b.ServiceKey().Signer(), jeff2Signer},
			false,
		)

		verifyStakingCollectionInfo(t, b, env, StakingCollectionInfo{
			accountAddress:     jeffAddress2.String(),
			unlockedBalance:    "60000000.000000",
			lockedBalance:      "0.00000000",
			unlockedTokensUsed: "40000000.00000000",
			lockedTokensUsed:   "0.00000000",
			unlockLimit:        "0.00000000",
			nodes:              ids,
			delegators:         []DelegatorIDs{},
		})

	})

}
