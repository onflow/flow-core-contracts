package test

import (
	"context"
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/cadence/runtime/interpreter"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

const (
	adminID        = "0000000000000000000000000000000000000000000000000000000000000001"
	admin          = 1
	joshID         = "0000000000000000000000000000000000000000000000000000000000000002"
	josh           = 2
	maxID          = "0000000000000000000000000000000000000000000000000000000000000003"
	max            = 3
	bastianID      = "0000000000000000000000000000000000000000000000000000000000000004"
	bastian        = 4
	accessID       = "0000000000000000000000000000000000000000000000000000000000000005"
	access         = 5
	executionID    = "0000000000000000000000000000000000000000000000000000000000000006"
	execution      = 6
	verificationID = "0000000000000000000000000000000000000000000000000000000000000007"
	verification   = 7
	newAddress     = 8

	nonexistantID = "0000000000000000000000000000000000000000000000000000000000383838383"

	firstDelegatorID        = 1
	firstDelegatorStringID  = "0001"
	secondDelegatorID       = 2
	secondDelegatorStringID = "0002"
)

func TestIDTableDeployment(t *testing.T) {

	t.Parallel()

	b, _ := newBlockchain()

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

	t.Run("Should be able to read empty table fields and initialized fields", func(t *testing.T) {

		result := executeScriptAndCheck(t, b, templates.GenerateReturnCurrentTableScript(env), nil)
		idArray := result.(cadence.Array).Values
		assert.Empty(t, idArray)

		result = executeScriptAndCheck(t, b, templates.GenerateReturnProposedTableScript(env), nil)

		idArray = result.(cadence.Array).Values
		assert.Empty(t, idArray)

		// Check that the stake requirements for each node role are initialized correctly

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		assertEqual(t, CadenceUFix64("250000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		assertEqual(t, CadenceUFix64("500000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		assertEqual(t, CadenceUFix64("1250000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		assertEqual(t, CadenceUFix64("135000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		assertEqual(t, CadenceUFix64("100.0"), result)

		// Check that the total tokens staked for each node role are initialized correctly

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		// Check that the reward ratios were initialized correctly for each node role

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardRatioScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		assertEqual(t, CadenceUFix64("0.168"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardRatioScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		assertEqual(t, CadenceUFix64("0.518"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardRatioScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		assertEqual(t, CadenceUFix64("0.078"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardRatioScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		assertEqual(t, CadenceUFix64("0.236"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardRatioScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		// Check that the weekly payout was initialized correctly

		result = executeScriptAndCheck(t, b, templates.GenerateGetWeeklyPayoutScript(env), nil)
		assertEqual(t, CadenceUFix64("1250000.0"), result)

		assertCandidateLimitsEquals(t, b, env, []uint64{10, 10, 10, 10, 10})

		assertRoleCountsEquals(t, b, env, []uint16{0, 0, 0, 0, 0})

	})

	t.Run("Shouldn't be able to change the cut percentage above 1", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateChangeCutScript(env), idTableAddress)

		_ = tx.AddArgument(CadenceUFix64("2.10"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			true,
		)
	})

	t.Run("Should be able to change the cut percentage", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateChangeCutScript(env), idTableAddress)

		_ = tx.AddArgument(CadenceUFix64("0.10"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetCutPercentageScript(env), nil)
		assertEqual(t, CadenceUFix64("0.10"), result)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateChangeCutScript(env), idTableAddress)

		_ = tx.AddArgument(CadenceUFix64("0.08"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCutPercentageScript(env), nil)
		assertEqual(t, CadenceUFix64("0.08"), result)
	})

	t.Run("Should be able to change the weekly payout", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateChangePayoutScript(env), idTableAddress)

		_ = tx.AddArgument(CadenceUFix64("5000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetWeeklyPayoutScript(env), nil)
		assertEqual(t, CadenceUFix64("5000000.0"), result)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateChangePayoutScript(env), idTableAddress)

		_ = tx.AddArgument(CadenceUFix64("1250000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetWeeklyPayoutScript(env), nil)
		assertEqual(t, CadenceUFix64("1250000.0"), result)
	})

	t.Run("Should be able to test scaling rewards properly", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateScaleRewardsTestScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)
	})
}

func TestIDTableTransferAdmin(t *testing.T) {

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

	//
	joshAccountKey, joshSigner := accountKeys.NewWithSigner()
	joshAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{joshAccountKey}, nil)

	t.Run("Should be able to transfer the admin capability to another account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateTransferAdminCapabilityScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress).
			AddAuthorizer(joshAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress, joshAddress},
			[]crypto.Signer{IDTableSigner, joshSigner},
			false,
		)
	})

	t.Run("Should be able to end epoch with the admin capability", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCapabilityEndEpochScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		nodeIDs := make([]string, 0)
		nodeIDDict := generateCadenceNodeDictionary(nodeIDs)

		err := tx.AddArgument(nodeIDDict)
		require.NoError(t, err)
		tx.AddArgument(CadenceUFix64("1300000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)
	})

}

func TestIDTableRegistration(t *testing.T) {

	b, _, accountKeys, env := newTestSetup(t)

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	idTableAddress, feesAddr := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, &env, true, []uint64{1, 1, 1, 1, 1})
	_, adminStakingKey, adminStakingPOP, _, adminNetworkingKey := generateKeysForNodeRegistration(t)
	mintTokensForAccount(t, b, env, idTableAddress, "1000000000.0")

	setNodeRoleSlotLimits(t, b, env, idTableAddress, IDTableSigner, [5]uint16{1, 1, 1, 1, 1})

	env.IDTableAddress = idTableAddress.Hex()
	env.FlowFeesAddress = feesAddr.Hex()

	// Create new user accounts
	joshAddress, _, joshSigner := newAccountWithAddress(b, accountKeys)
	_, joshStakingKey, joshStakingPOP, _, joshNetworkingKey := generateKeysForNodeRegistration(t)
	mintTokensForAccount(t, b, env, joshAddress, "1000000000.0")

	// Create a new user account
	maxAddress, _, maxSigner := newAccountWithAddress(b, accountKeys)
	_, maxStakingKey, maxStakingPOP, _, maxNetworkingKey := generateKeysForNodeRegistration(t)
	mintTokensForAccount(t, b, env, maxAddress, "1000000000.0")

	// Create a new user account
	bastianAddress, _, bastianSigner := newAccountWithAddress(b, accountKeys)
	_, bastianStakingKey, bastianStakingPOP, _, bastianNetworkingKey := generateKeysForNodeRegistration(t)
	mintTokensForAccount(t, b, env, bastianAddress, "1000000000.0")

	// Create a new user account for access node
	accessAddress, _, accessSigner := newAccountWithAddress(b, accountKeys)
	_, accessStakingKey, accessStakingPOP, _, accessNetworkingKey := generateKeysForNodeRegistration(t)
	mintTokensForAccount(t, b, env, accessAddress, "1000000000.0")

	committed := make(map[string]interpreter.UFix64Value)

	t.Run("Shouldn't be able to create invalid Node structs", func(t *testing.T) {

		var amountToCommit interpreter.UFix64Value = 25000000000000

		registerNode(t, b, env,
			idTableAddress,
			IDTableSigner,
			// Invalid ID: Too short
			"3039",
			fmt.Sprintf("%0128d", admin),
			adminNetworkingKey,
			adminStakingKey,
			adminStakingPOP,
			amountToCommit,
			committed[adminID],
			1,
			true)

		registerNode(t, b, env,
			idTableAddress,
			IDTableSigner,
			adminID,
			fmt.Sprintf("%0128d", admin),
			adminNetworkingKey,
			adminStakingKey,
			adminStakingPOP,
			amountToCommit,
			committed[adminID],
			// Invalid Role: Greater than 5
			6,
			true)

		registerNode(t, b, env,
			idTableAddress,
			IDTableSigner,
			adminID,
			fmt.Sprintf("%0128d", admin),
			adminNetworkingKey,
			adminStakingKey,
			adminStakingPOP,
			amountToCommit,
			committed[adminID],
			// Invalid Role: Less than 1
			0,
			true)

		registerNode(t, b, env,
			idTableAddress,
			IDTableSigner,
			adminID,
			// Invalid Networking Address: Length cannot be zero
			"",
			adminNetworkingKey,
			adminStakingKey,
			adminStakingPOP,
			amountToCommit,
			committed[adminID],
			1,
			true)

		registerNode(t, b, env,
			idTableAddress,
			IDTableSigner,
			adminID,
			fmt.Sprintf("%0128d", admin),
			// Invalid Networking Key: Length is correct, but not a valid ECDSA Key
			fmt.Sprintf("%0128d", admin),
			adminStakingKey,
			adminStakingPOP,
			amountToCommit,
			committed[adminID],
			1,
			true)

		registerNode(t, b, env,
			idTableAddress,
			IDTableSigner,
			adminID,
			fmt.Sprintf("%0128d", admin),
			adminNetworkingKey,
			// Invalid Staking Key: Length is correct, but not a valid BLS Key
			fmt.Sprintf("%0192d", admin),
			adminStakingPOP,
			amountToCommit,
			committed[adminID],
			1,
			true)

		registerNode(t, b, env,
			idTableAddress,
			IDTableSigner,
			adminID,
			fmt.Sprintf("%0128d", admin),
			adminNetworkingKey,
			adminStakingKey,
			// Invalid Staking Key POP: Length is correct, but not a valid POP
			fmt.Sprintf("%096d", admin),
			amountToCommit,
			committed[adminID],
			1,
			true)

	})

	t.Run("Should be able to create a valid Node struct and not create duplicates", func(t *testing.T) {

		var amountToCommit interpreter.UFix64Value = 25000000000000

		registerNode(t, b, env,
			idTableAddress,
			IDTableSigner,
			adminID,
			fmt.Sprintf("%0128d", admin),
			adminNetworkingKey,
			adminStakingKey,
			adminStakingPOP,
			amountToCommit,
			committed[adminID],
			1,
			false)

		result := executeScriptAndCheck(t, b, templates.GenerateReturnTableScript(env), nil)

		idArray := result.(cadence.Array).Values
		assert.Len(t, idArray, 1)

		// Should not be on the proposed list yet because it isn't approved
		result = executeScriptAndCheck(t, b, templates.GenerateReturnProposedTableScript(env), nil)

		idArray = result.(cadence.Array).Values
		assert.Len(t, idArray, 0)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRoleScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, cadence.NewUInt8(1), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetNetworkingAddressScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceString(fmt.Sprintf("%0128d", admin)), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetNetworkingKeyScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceString(adminNetworkingKey), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakingKeyScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceString(adminStakingKey), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetInitialWeightScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, cadence.NewUInt64(0), result)

		registerNode(t, b, env,
			idTableAddress,
			IDTableSigner,
			// Invalid: Admin ID is already in use
			adminID,
			fmt.Sprintf("%0128d", josh),
			joshNetworkingKey,
			joshStakingKey,
			joshStakingPOP,
			amountToCommit,
			committed[adminID],
			1,
			true)

		registerNode(t, b, env,
			joshAddress,
			joshSigner,
			joshID,
			// Invalid: first admin networking address is already in use
			fmt.Sprintf("%0128d", admin),
			joshNetworkingKey,
			joshStakingKey,
			joshStakingPOP,
			amountToCommit,
			committed[adminID],
			1,
			true)

		registerNode(t, b, env,
			joshAddress,
			joshSigner,
			joshID,
			fmt.Sprintf("%0128d", josh),
			// Invalid: first admin networking key is already in use
			adminNetworkingKey,
			joshStakingKey,
			joshStakingPOP,
			amountToCommit,
			committed[adminID],
			1,
			true)

		registerNode(t, b, env,
			joshAddress,
			joshSigner,
			joshID,
			fmt.Sprintf("%0128d", josh),
			joshNetworkingKey,
			// Invalid: first admin stake key is already in use
			adminStakingKey,
			joshStakingPOP,
			amountToCommit,
			committed[adminID],
			1,
			true)

	})

	t.Run("Should be able to change the networking address properly", func(t *testing.T) {

		// Should fail because the networking address is the wrong length
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateNetworkingAddressScript(env), idTableAddress)

		tx.AddArgument(CadenceString(fmt.Sprintf("%0511d", josh)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			true,
		)

		// Should fail because the networking address is already claimed
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateNetworkingAddressScript(env), idTableAddress)

		tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", admin)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			true,
		)

		// Should succeed because it is a new networking address and it is the correct length
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateNetworkingAddressScript(env), idTableAddress)

		tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", newAddress)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNetworkingAddressScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceString(fmt.Sprintf("%0128d", newAddress)), result)

		// Should fail because it is the same networking address as the one that was just updated
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateNetworkingAddressScript(env), idTableAddress)

		tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", newAddress)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			true,
		)

		// Should succeed because the old networking address is claimable after updating
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUpdateNetworkingAddressScript(env), idTableAddress)

		tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", admin)))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

	})

	t.Run("Shouldn't be able to remove a Node that doesn't exist", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRemoveNodeScript(env), idTableAddress)

		_ = tx.AddArgument(CadenceString(nonexistantID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			true,
		)
	})

	t.Run("Should be able to create more valid Node structs", func(t *testing.T) {

		var amountToCommit interpreter.UFix64Value = 50000000000000

		committed[joshID] = registerNode(t, b, env,
			joshAddress,
			joshSigner,
			joshID,
			fmt.Sprintf("%0128d", josh),
			joshNetworkingKey,
			joshStakingKey,
			joshStakingPOP,
			amountToCommit,
			committed[joshID],
			2,
			false)

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(committed[joshID].String()), result)

		amountToCommit = 135000000000000

		committed[maxID] = registerNode(t, b, env,
			maxAddress,
			maxSigner,
			maxID,
			fmt.Sprintf("%0128d", max),
			maxNetworkingKey,
			maxStakingKey,
			maxStakingPOP,
			amountToCommit,
			committed[maxID],
			3,
			false)

		amountToCommit = 5000000000000

		committed[accessID] = registerNode(t, b, env,
			accessAddress,
			accessSigner,
			accessID,
			fmt.Sprintf("%0128d", access),
			accessNetworkingKey,
			accessStakingKey,
			accessStakingPOP,
			amountToCommit,
			committed[accessID],
			5,
			false)

		result = executeScriptAndCheck(t, b, templates.GenerateReturnCurrentTableScript(env), nil)

		idArray := result.(cadence.Array).Values
		assert.Len(t, idArray, 0)
	})

	t.Run("Shouldn't be able to register a node if it would be more than the candidate limit", func(t *testing.T) {

		var amountToCommit interpreter.UFix64Value = 48000000000000

		registerNode(t, b, env,
			bastianAddress,
			bastianSigner,
			bastianID,
			fmt.Sprintf("%0128d", bastian),
			bastianNetworkingKey,
			bastianStakingKey,
			bastianStakingPOP,
			amountToCommit,
			committed[bastianID],
			5,
			true)
	})

	t.Run("Should be able to set new candidate limit and register the node that was previously rejected", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetCandidateLimitsScript(env), idTableAddress)

		err := tx.AddArgument(cadence.NewUInt8(5))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewUInt64(2))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		// read the candidate nodes limits and make sure they have changed
		assertCandidateLimitsEquals(t, b, env, []uint64{1, 1, 1, 1, 2})

		var amountToCommit interpreter.UFix64Value = 48000000000000

		// Try to register the node again
		// it should succeed this time
		registerNode(t, b, env,
			bastianAddress,
			bastianSigner,
			bastianID,
			fmt.Sprintf("%0128d", bastian),
			bastianNetworkingKey,
			bastianStakingKey,
			bastianStakingPOP,
			amountToCommit,
			committed[bastianID],
			5,
			false)

		// create expected candidate node list
		candidates := CandidateNodes{
			collector:    []string{adminID},
			consensus:    []string{joshID},
			execution:    []string{maxID},
			verification: []string{},
			access:       []string{accessID, bastianID},
		}

		assertCandidateNodeListEquals(t, b, env, candidates)
	})

	t.Run("Should remove nodes from the candidate list if they unstake below the minimum", func(t *testing.T) {

		var amountToRequest interpreter.UFix64Value = 47990100000000

		requestUnstaking(t, b, env,
			bastianAddress,
			bastianSigner,
			amountToRequest,
			committed[bastianID],
			committed[bastianID],
			committed[bastianID],
			false,
		)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeAllScript(env), accessAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{accessAddress},
			[]crypto.Signer{accessSigner},
			false,
		)

		// New expected list should not include either
		// of the newly unstaked access nodes
		candidates := CandidateNodes{
			collector:    []string{adminID},
			consensus:    []string{joshID},
			execution:    []string{maxID},
			verification: []string{},
			access:       []string{},
		}

		assertCandidateNodeListEquals(t, b, env, candidates)
		assertRoleCountsEquals(t, b, env, []uint16{0, 0, 0, 0, 0})
	})
}

// Tests for approvals
// TODO: Move approval tests from TestIDTableStaking
func TestIDTableApprovals(t *testing.T) {

	t.Parallel()

	b, _ := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
		BurnerAddress:        emulatorServiceAccount,
		StorageFeesAddress:   emulatorServiceAccount,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	_, adminStakingKey, adminStakingPoP, _, adminNetworkingKey := generateKeysForNodeRegistration(t)
	idTableAddress, feesAddr := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, &env, true, []uint64{3, 3, 3, 3, 3})
	mintTokensForAccount(t, b, env, idTableAddress, "1000000000.0")

	accessAddress, _, accessSigner := newAccountWithAddress(b, accountKeys)
	_, accessStakingKey, accessStakingPOP, _, accessNetworkingKey := generateKeysForNodeRegistration(t)
	mintTokensForAccount(t, b, env, accessAddress, "1000000000.0")

	joshAddress, _, joshSigner := newAccountWithAddress(b, accountKeys)
	_, joshStakingKey, joshStakingPOP, _, joshNetworkingKey := generateKeysForNodeRegistration(t)
	mintTokensForAccount(t, b, env, joshAddress, "1000000000.0")

	env.IDTableAddress = idTableAddress.Hex()
	env.FlowFeesAddress = feesAddr.Hex()

	committed := make(map[string]interpreter.UFix64Value)

	var amountToCommit interpreter.UFix64Value = 25000000000000
	committed[adminID] = registerNode(t, b, env,
		idTableAddress,
		IDTableSigner,
		adminID,
		fmt.Sprintf("%0128d", admin),
		adminNetworkingKey,
		adminStakingKey,
		adminStakingPoP,
		amountToCommit,
		committed[adminID],
		1,
		false)

	nodeIDs := make([]string, 2)
	nodeIDs[0] = accessID
	nodeIDs[1] = adminID
	nodeIDDict := generateCadenceNodeDictionary(nodeIDs)
	initialNodeIDs := cadence.NewArray([]cadence.Value{CadenceString(adminID), CadenceString(accessID)}).WithType(cadence.NewVariableSizedArrayType(cadence.StringType))

	// Update the access node minimum to zero
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateChangeMinimumsScript(env), idTableAddress)
	err := tx.AddArgument(cadence.NewArray([]cadence.Value{CadenceUFix64("250000.0"), CadenceUFix64("250000.0"), CadenceUFix64("1250000.0"), CadenceUFix64("135000.0"), CadenceUFix64("0.0")}))
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	// Register an access node
	amountToCommit = 00000000
	committed[adminID] = registerNode(t, b, env,
		accessAddress,
		accessSigner,
		accessID,
		fmt.Sprintf("%0128d", access),
		accessNetworkingKey,
		accessStakingKey,
		accessStakingPOP,
		amountToCommit,
		committed[accessID],
		5,
		false)

	// Register another
	committed[adminID] = registerNode(t, b, env,
		joshAddress,
		joshSigner,
		joshID,
		fmt.Sprintf("%0128d", josh),
		joshNetworkingKey,
		joshStakingKey,
		joshStakingPOP,
		amountToCommit,
		committed[joshID],
		5,
		false)

	// Access nodes should not be on the proposed list because they haven't been selected yet
	// The collector node is not approved, so it is also not included
	result := executeScriptAndCheck(t, b, templates.GenerateReturnProposedTableScript(env), nil)
	idArray := result.(cadence.Array).Values
	assert.Len(t, idArray, 0)

	// Update the access node minimum to 100
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateChangeMinimumsScript(env), idTableAddress)
	err = tx.AddArgument(cadence.NewArray([]cadence.Value{CadenceUFix64("250000.0"), CadenceUFix64("250000.0"), CadenceUFix64("1250000.0"), CadenceUFix64("135000.0"), CadenceUFix64("100.0")}))
	require.NoError(t, err)
	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	// None of the access nodes are on the proposed list because they are below the minimum and not approved
	result = executeScriptAndCheck(t, b, templates.GenerateReturnProposedTableScript(env), nil)
	idArray = result.(cadence.Array).Values
	assert.Len(t, idArray, 0)

	t.Run("Should be able to approve an access node that isn't above the minimum even if access is below the minimum", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateAddApprovedAndLimitsScript(env), idTableAddress)

		err := tx.AddArgument(cadence.NewArray([]cadence.Value{CadenceString(adminID), CadenceString(accessID)}))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)
		assertApprovedListEquals(t, b, env, initialNodeIDs)

		// Access node should still not be on the proposed list because it
		// has not been selected by slot selection
		result = executeScriptAndCheck(t, b, templates.GenerateReturnProposedTableScript(env), nil)

		idArray = result.(cadence.Array).Values
		assert.Len(t, idArray, 1)

		assertCandidateLimitsEquals(t, b, env, []uint64{3, 3, 3, 3, 3})

		result := executeScriptAndCheck(t, b, templates.GenerateGetSlotLimitsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		assertEqual(t, cadence.NewUInt16(10001), result)
		result = executeScriptAndCheck(t, b, templates.GenerateGetSlotLimitsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		assertEqual(t, cadence.NewUInt16(10001), result)

	})

	// removing an existing node from the approved node list should remove that node
	t.Run("Should be able to remove a node from the approved list", func(t *testing.T) {
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRemoveApprovedNodesScript(env), idTableAddress)

		removingNodeIDs := cadence.NewArray([]cadence.Value{CadenceString(adminID)})
		err := tx.AddArgument(removingNodeIDs)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		expected := cadence.NewArray([]cadence.Value{CadenceString(accessID)}).WithType(cadence.NewVariableSizedArrayType(cadence.StringType))
		assertApprovedListEquals(t, b, env, expected)
	})

	// End the staking auction, which adds the node back to the approved list
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEndStakingScript(env), idTableAddress)

	err = tx.AddArgument(nodeIDDict)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	assertRoleCountsEquals(t, b, env, []uint16{1, 0, 0, 0, 1})

	// removing an existing node from the approved node list should remove that node
	t.Run("Removing a node from the approved list not during staking auction should refund it immediately", func(t *testing.T) {
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRemoveApprovedNodesScript(env), idTableAddress)

		removingNodeIDs := cadence.NewArray([]cadence.Value{CadenceString(adminID)})
		err := tx.AddArgument(removingNodeIDs)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64("250000.0"), result)

		assertRoleCountsEquals(t, b, env, []uint16{0, 0, 0, 0, 1})

	})

	// Move tokens and start a new staking auction
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateMoveTokensScript(env), idTableAddress)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	// The current participant access node is participating with zero stake even though the minimum is 100,
	// because it was approved by the admin
	assertRoleCountsEquals(t, b, env, []uint16{0, 0, 0, 0, 1})
	result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(accessID))})
	assertEqual(t, CadenceUFix64("0.0"), result)
	result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(accessID))})
	assertEqual(t, CadenceUFix64("0.0"), result)
	result = executeScriptAndCheck(t, b, templates.GenerateReturnCurrentTableScript(env), nil)
	idArray = result.(cadence.Array).Values
	assert.Len(t, idArray, 1)
	assertEqual(t, CadenceString(accessID), idArray[0])

	t.Run("Adding new stake to a zero-stake access node who is already a participant should not add them to the candidate list", func(t *testing.T) {
		amountToCommit = 10000000000
		commitNewTokens(t, b, env,
			accessAddress,
			accessSigner,
			amountToCommit,
			committed[accessID],
			false)

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(accessID))})
		assertEqual(t, CadenceUFix64("100.0"), result)

		// Check that they were not added to the candidate node list
		// expected candidate node list should be empty
		candidates := CandidateNodes{
			collector:    []string{},
			consensus:    []string{},
			execution:    []string{},
			verification: []string{},
			access:       []string{},
		}

		assertCandidateNodeListEquals(t, b, env, candidates)

	})

	// Approve josh access node
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateAddApprovedAndLimitsScript(env), idTableAddress)

	err = tx.AddArgument(cadence.NewArray([]cadence.Value{CadenceString(adminID), CadenceString(accessID), CadenceString(joshID)}))
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	t.Run("Adding new stake to a non-participant, approved, zero-stake access node should add them to the candidate list", func(t *testing.T) {
		amountToCommit = 10000000000
		commitNewTokens(t, b, env,
			joshAddress,
			joshSigner,
			amountToCommit,
			committed[joshID],
			false)

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64("100.0"), result)

		// Check that they were added to the candidate node list
		candidates := CandidateNodes{
			collector:    []string{},
			consensus:    []string{},
			execution:    []string{},
			verification: []string{},
			access:       []string{joshID},
		}

		assertCandidateNodeListEquals(t, b, env, candidates)

	})
}

func TestIDTableStaking(t *testing.T) {

	t.Parallel()

	b, _ := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
		BurnerAddress:        emulatorServiceAccount,
		StorageFeesAddress:   emulatorServiceAccount,
	}

	accountKeys := test.AccountKeyGenerator()

	var totalPayout interpreter.UFix64Value = 125000000000000 // 1.25M
	var cutPercentage interpreter.UFix64Value = 8000000       // 8.0 %

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	_, adminStakingKey, adminStakingPOP, _, adminNetworkingKey := generateKeysForNodeRegistration(t)
	idTableAddress, feesAddr := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, &env, true, []uint64{3, 3, 3, 3, 3})
	mintTokensForAccount(t, b, env, idTableAddress, "1000000000.0")

	env.IDTableAddress = idTableAddress.Hex()
	env.FlowFeesAddress = feesAddr.Hex()

	var totalStaked interpreter.UFix64Value = 0

	committed := make(map[string]interpreter.UFix64Value)
	staked := make(map[string]interpreter.UFix64Value)
	request := make(map[string]interpreter.UFix64Value)
	unstaking := make(map[string]interpreter.UFix64Value)
	unstaked := make(map[string]interpreter.UFix64Value)
	rewards := make(map[string]interpreter.UFix64Value)

	// Create new user accounts
	joshAddress, _, joshSigner := newAccountWithAddress(b, accountKeys)
	_, joshStakingKey, joshStakingPOP, _, joshNetworkingKey := generateKeysForNodeRegistration(t)
	mintTokensForAccount(t, b, env, joshAddress, "1000000000.0")

	maxAddress, _, maxSigner := newAccountWithAddress(b, accountKeys)
	_, maxStakingKey, maxStakingPOP, _, maxNetworkingKey := generateKeysForNodeRegistration(t)
	mintTokensForAccount(t, b, env, maxAddress, "1000000000.0")

	bastianAddress, _, bastianSigner := newAccountWithAddress(b, accountKeys)
	_, bastianStakingKey, bastianStakingPOP, _, bastianNetworkingKey := generateKeysForNodeRegistration(t)
	mintTokensForAccount(t, b, env, bastianAddress, "1000000000.0")

	accessAddress, _, accessSigner := newAccountWithAddress(b, accountKeys)
	_, accessStakingKey, accessStakingPOP, _, accessNetworkingKey := generateKeysForNodeRegistration(t)
	mintTokensForAccount(t, b, env, accessAddress, "1000000000.0")

	// Create new delegator user accounts
	adminDelegatorAddress, _, adminDelegatorSigner := newAccountWithAddress(b, accountKeys)
	mintTokensForAccount(t, b, env, adminDelegatorAddress, "1000000000.0")

	joshDelegatorOneAddress, _, joshDelegatorOneSigner := newAccountWithAddress(b, accountKeys)
	mintTokensForAccount(t, b, env, joshDelegatorOneAddress, "1000000000.0")

	maxDelegatorOneAddress, _, maxDelegatorOneSigner := newAccountWithAddress(b, accountKeys)
	mintTokensForAccount(t, b, env, maxDelegatorOneAddress, "1000000000.0")

	maxDelegatorTwoAddress, _, maxDelegatorTwoSigner := newAccountWithAddress(b, accountKeys)
	mintTokensForAccount(t, b, env, maxDelegatorTwoAddress, "1000000000.0")

	// Register the First nodes
	var amountToCommit interpreter.UFix64Value = 25000000000000
	committed[adminID] = registerNode(t, b, env,
		idTableAddress,
		IDTableSigner,
		adminID,
		fmt.Sprintf("%0128d", admin),
		adminNetworkingKey,
		adminStakingKey,
		adminStakingPOP,
		amountToCommit,
		committed[adminID],
		1,
		false)

	result := executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
	assertEqual(t, CadenceUFix64(staked[adminID].String()), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
	assertEqual(t, CadenceUFix64(committed[adminID].String()), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
	assertEqual(t, CadenceUFix64(unstaked[adminID].String()), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
	assertEqual(t, CadenceUFix64(unstaking[adminID].String()), result)

	amountToCommit = 50000000000000

	committed[joshID] = registerNode(t, b, env,
		joshAddress,
		joshSigner,
		joshID,
		fmt.Sprintf("%0128d", josh),
		joshNetworkingKey,
		joshStakingKey,
		joshStakingPOP,
		amountToCommit,
		committed[joshID],
		2,
		false)

	amountToCommit = 135000000000000

	committed[maxID] = registerNode(t, b, env,
		maxAddress,
		maxSigner,
		maxID,
		fmt.Sprintf("%0128d", max),
		maxNetworkingKey,
		maxStakingKey,
		maxStakingPOP,
		amountToCommit,
		committed[maxID],
		3,
		false)

	amountToCommit = 5000000000000

	committed[accessID] = registerNode(t, b, env,
		accessAddress,
		accessSigner,
		accessID,
		fmt.Sprintf("%0128d", access),
		accessNetworkingKey,
		accessStakingKey,
		accessStakingPOP,
		amountToCommit,
		committed[accessID],
		5,
		false)

	t.Run("Should be able to commit additional tokens for max's node", func(t *testing.T) {

		var amountToCommit interpreter.UFix64Value = 10000000000000

		committed[maxID] = commitNewTokens(t, b, env,
			maxAddress,
			maxSigner,
			amountToCommit,
			committed[maxID],
			false)

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64(committed[maxID].String()), result)
	})

	t.Run("Should not be able request unstaking for more than is available", func(t *testing.T) {

		var amountToRequest interpreter.UFix64Value = 500000000000000

		requestUnstaking(t, b, env,
			maxAddress,
			maxSigner,
			amountToRequest,
			committed[maxID],
			unstaked[maxID],
			request[maxID],
			true,
		)
	})

	t.Run("Should be able to request unstaking which moves from comitted to unstaked", func(t *testing.T) {

		var amountToRequest interpreter.UFix64Value = 2000000000000

		committed[joshID], unstaked[joshID], request[joshID] = requestUnstaking(t, b, env,
			joshAddress,
			joshSigner,
			amountToRequest,
			committed[joshID],
			unstaked[joshID],
			request[joshID],
			false,
		)

		amountToRequest = 10000000000000

		committed[maxID], unstaked[maxID], request[maxID] = requestUnstaking(t, b, env,
			maxAddress,
			maxSigner,
			amountToRequest,
			committed[maxID],
			unstaked[maxID],
			request[maxID],
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64(committed[maxID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64(unstaked[maxID].String()), result)
	})

	t.Run("Should be able to withdraw tokens from unstaked", func(t *testing.T) {

		unstaked[maxID] = unstaked[maxID] - 5000000000000

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateWithdrawUnstakedTokensScript(env), maxAddress)

		err := tx.AddArgument(CadenceUFix64("50000.0"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{maxAddress},
			[]crypto.Signer{maxSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64(unstaked[maxID].String()), result)
	})

	t.Run("Should be able to commit unstaked tokens", func(t *testing.T) {

		var amountToCommit interpreter.UFix64Value = 5000000000000

		committed[maxID], unstaked[maxID] = commitUnstaked(t, b, env,
			maxAddress,
			maxSigner,
			amountToCommit,
			committed[maxID],
			unstaked[maxID],
			false)

		result := executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64(unstaked[maxID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64(committed[maxID].String()), result)
	})

	// [josh, max]
	nodeIDs := make([]string, 2)
	nodeIDs[0] = joshID
	nodeIDs[1] = maxID
	nodeIDDict := generateCadenceNodeDictionary(nodeIDs)
	initialNodeIDs := cadence.NewArray([]cadence.Value{CadenceString(maxID), CadenceString(joshID)}).WithType(cadence.NewVariableSizedArrayType(cadence.StringType))

	t.Run("Should be able to add nodes to approved node list", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetApprovedNodesScript(env), idTableAddress)

		err := tx.AddArgument(nodeIDDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		// adding an existing node to the approved node list should be a no-op
		t.Run("existing node", func(t *testing.T) {
			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateAddApprovedNodesScript(env), idTableAddress)

			addingNodeIDs := cadence.NewArray([]cadence.Value{CadenceString(joshID)})
			err := tx.AddArgument(addingNodeIDs)
			require.NoError(t, err)

			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]crypto.Signer{IDTableSigner},
				false,
			)

			assertApprovedListEquals(t, b, env, initialNodeIDs)
		})

		// adding a new node should result in that node being added to the existing list
		t.Run("new node", func(t *testing.T) {
			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateAddApprovedNodesScript(env), idTableAddress)

			// should now be [josh, max, admin]
			addingNodeIDs := cadence.NewArray([]cadence.Value{CadenceString(adminID)})
			err := tx.AddArgument(addingNodeIDs)
			require.NoError(t, err)

			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]crypto.Signer{IDTableSigner},
				false,
			)

			expected := cadence.NewArray([]cadence.Value{CadenceString(maxID), CadenceString(adminID), CadenceString(joshID)}).WithType(cadence.NewVariableSizedArrayType(cadence.StringType))
			assertApprovedListEquals(t, b, env, expected)
		})
	})

	t.Run("Should be able to remove nodes from approved node list", func(t *testing.T) {

		// [josh, max]
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetApprovedNodesScript(env), idTableAddress)

		err := tx.AddArgument(nodeIDDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		// removing an unknown node should be a no-op
		t.Run("unknown node", func(t *testing.T) {
			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRemoveApprovedNodesScript(env), idTableAddress)

			removingNodeIDs := cadence.NewArray([]cadence.Value{CadenceString(nonexistantID)})
			err := tx.AddArgument(removingNodeIDs)
			require.NoError(t, err)

			signAndSubmit(
				t, b, tx,
				[]flow.Address{idTableAddress},
				[]crypto.Signer{IDTableSigner},
				false,
			)

			expected := cadence.NewArray([]cadence.Value{CadenceString(maxID), CadenceString(joshID)}).WithType(cadence.NewVariableSizedArrayType(cadence.StringType))
			assertApprovedListEquals(t, b, env, expected)
		})
	})

	fourNodeIDs := make([]string, 4)
	fourNodeIDs[0] = adminID
	fourNodeIDs[1] = joshID
	fourNodeIDs[2] = maxID
	fourNodeIDs[3] = accessID
	fourNodeIDDict := generateCadenceNodeDictionary(fourNodeIDs)

	t.Run("Should be able to set and get the approved node list", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetApprovedNodesScript(env), idTableAddress)

		err := tx.AddArgument(fourNodeIDDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		// read the approved nodes list and check that our node ids exists
		result := executeScriptAndCheck(t, b, templates.GenerateGetApprovedNodesScript(env), nil)
		idArray := result.(cadence.Array).Values
		assert.Len(t, idArray, 4)

		// read the proposed nodes table and check that our node ids exists
		// The access node is not on the proposed list yet because it hasn't been selected
		// by slot selection
		result = executeScriptAndCheck(t, b, templates.GenerateReturnProposedTableScript(env), nil)
		idArray = result.(cadence.Array).Values
		assert.Len(t, idArray, 2)
	})

	t.Run("Should be able to end the staking auction, which removes insufficiently staked nodes", func(t *testing.T) {

		unstaked[joshID] = unstaked[joshID] + committed[joshID]
		committed[joshID] = 0

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndStakingScript(env), idTableAddress)

		err := tx.AddArgument(fourNodeIDDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		// expected candidate node list should be empty
		candidates := CandidateNodes{
			collector:    []string{},
			consensus:    []string{},
			execution:    []string{},
			verification: []string{},
			access:       []string{},
		}

		assertCandidateNodeListEquals(t, b, env, candidates)
		assertRoleCountsEquals(t, b, env, []uint16{1, 0, 1, 0, 1})

		result := executeScriptAndCheck(t, b, templates.GenerateReturnProposedTableScript(env), nil)

		idArray := result.(cadence.Array).Values
		assert.Len(t, idArray, 3)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(unstaked[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(committed[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(unstaked[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(committed[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64(unstaked[maxID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64(committed[maxID].String()), result)

	})

	t.Run("Should pay rewards, but no balances are increased because nobody is staked", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GeneratePayRewardsScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(unstaked[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(unstaked[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64(unstaked[maxID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(rewards[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(rewards[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64(rewards[maxID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(accessID))})
		assertEqual(t, CadenceUFix64(rewards[accessID].String()), result)

	})

	t.Run("Should not be able to perform additional staking operations when staking isn't enabled", func(t *testing.T) {

		var amountToCommit interpreter.UFix64Value = 100000000000

		commitNewTokens(t, b, env,
			maxAddress,
			maxSigner,
			amountToCommit,
			committed[maxID],
			true)

		commitUnstaked(t, b, env,
			maxAddress,
			maxSigner,
			amountToCommit,
			committed[maxID],
			unstaked[maxID],
			true)

		commitRewarded(t, b, env,
			maxAddress,
			maxSigner,
			amountToCommit,
			committed[maxID],
			rewards[maxID],
			true)

		var amountToRequest interpreter.UFix64Value = 5000000000000

		requestUnstaking(t, b, env,
			maxAddress,
			maxSigner,
			amountToRequest,
			committed[maxID],
			unstaked[maxID],
			request[maxID],
			true,
		)

	})

	t.Run("Should not be able to register accounts to delegate if staking isn't enabled", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterDelegatorScript(env), maxDelegatorOneAddress)

		err := tx.AddArgument(cadence.String(maxID))
		require.NoError(t, err)

		tokenAmount, err := cadence.NewUFix64("50.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{maxDelegatorOneAddress},
			[]crypto.Signer{maxDelegatorOneSigner},
			true,
		)
	})

	t.Run("Should Move committed tokens to staked buckets", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateMoveTokensScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		committed[adminID], staked[adminID], request[adminID], unstaking[adminID], unstaked[adminID], totalStaked = moveTokens(
			committed[adminID], staked[adminID], request[adminID], unstaking[adminID], unstaked[adminID], totalStaked)

		committed[joshID], staked[joshID], request[joshID], unstaking[joshID], unstaked[joshID], totalStaked = moveTokens(
			committed[joshID], staked[joshID], request[joshID], unstaking[joshID], unstaked[joshID], totalStaked)

		committed[maxID], staked[maxID], request[maxID], unstaking[maxID], unstaked[maxID], totalStaked = moveTokens(
			committed[maxID], staked[maxID], request[maxID], unstaking[maxID], unstaked[maxID], totalStaked)

		committed[accessID], staked[accessID], request[accessID], unstaking[accessID], unstaked[accessID], totalStaked = moveTokens(
			committed[accessID], staked[accessID], request[accessID], unstaking[accessID], unstaked[accessID], totalStaked)

		result := executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(unstaked[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(unstaked[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64(unstaked[maxID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(committed[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(committed[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64(committed[maxID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(staked[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(staked[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64(staked[maxID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(accessID))})
		assertEqual(t, CadenceUFix64(staked[accessID].String()), result)

		assertRoleCountsEquals(t, b, env, []uint16{1, 0, 1, 0, 1})
	})

	t.Run("Should be able to commit unstaked and new tokens from the node who was not included", func(t *testing.T) {

		var amountToCommit interpreter.UFix64Value = 48000000000000

		committed[joshID], unstaked[joshID] = commitUnstaked(t, b, env,
			joshAddress,
			joshSigner,
			amountToCommit,
			committed[joshID],
			unstaked[joshID],
			false)

		amountToCommit = 10000000000000

		committed[joshID] = commitNewTokens(t, b, env,
			joshAddress,
			joshSigner,
			amountToCommit,
			committed[joshID],
			false)

		// Re-add the node to the approve list since it was removed during the last end staking
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetApprovedNodesScript(env), idTableAddress)

		err := tx.AddArgument(fourNodeIDDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateReturnProposedTableScript(env), nil)

		idArray := result.(cadence.Array).Values
		assert.Len(t, idArray, 4)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(unstaked[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(committed[joshID].String()), result)
	})

	t.Run("Should be able to request unstaking from a staked node", func(t *testing.T) {

		var amountToRequest interpreter.UFix64Value = 5000000000000

		committed[adminID], unstaked[adminID], request[adminID] = requestUnstaking(t, b, env,
			idTableAddress,
			IDTableSigner,
			amountToRequest,
			committed[adminID],
			unstaked[adminID],
			request[adminID],
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(request[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(unstaked[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(staked[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64((committed[adminID].Plus(stubInterpreter(), staked[adminID].Minus(stubInterpreter(), request[adminID], interpreter.EmptyLocationRange), interpreter.EmptyLocationRange)).String()), result)

		// josh, max, and access are proposed
		result = executeScriptAndCheck(t, b, templates.GenerateReturnProposedTableScript(env), nil)

		idArray := result.(cadence.Array).Values
		assert.Len(t, idArray, 3)

		// admin, max, and access are staked
		result = executeScriptAndCheck(t, b, templates.GenerateReturnCurrentTableScript(env), nil)

		idArray = result.(cadence.Array).Values
		assert.Len(t, idArray, 3)
	})

	/************* Start of Delegation Tests *******************/

	t.Run("Should not be able to register a delegator below the minimum", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterDelegatorScript(env), maxDelegatorOneAddress)

		err := tx.AddArgument(cadence.String(maxID))
		require.NoError(t, err)

		tokenAmount, _ := cadence.NewUFix64("0.0")
		tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{maxDelegatorOneAddress},
			[]crypto.Signer{maxDelegatorOneSigner},
			true,
		)
	})

	t.Run("Should be able to register account to delegate to josh", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterDelegatorScript(env), joshDelegatorOneAddress)

		err := tx.AddArgument(cadence.String(joshID))
		require.NoError(t, err)

		tokenAmount, _ := cadence.NewUFix64("50.0")
		tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			false,
		)
	})

	t.Run("Should not be able to register account to delegate to the admin address, because it has insufficient stake committed", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterDelegatorScript(env), adminDelegatorAddress)

		err := tx.AddArgument(cadence.String(adminID))
		require.NoError(t, err)

		tokenAmount, _ := cadence.NewUFix64("50.0")
		tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminDelegatorAddress},
			[]crypto.Signer{adminDelegatorSigner},
			true,
		)
	})

	t.Run("Should not be able to register account to delegate to the access node, because access nodes are not allowed to be delegated to", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterDelegatorScript(env), adminDelegatorAddress)

		err := tx.AddArgument(cadence.String(accessID))
		require.NoError(t, err)

		tokenAmount, _ := cadence.NewUFix64("50.0")
		tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{adminDelegatorAddress},
			[]crypto.Signer{adminDelegatorSigner},
			true,
		)
	})

	t.Run("Should be able to delegate new tokens to josh", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorStakeNewScript(env), joshDelegatorOneAddress)
		_ = tx.AddArgument(CadenceUFix64("99950.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			false,
		)

		committed[joshID+firstDelegatorStringID] = 10000000000000

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(committed[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64((committed[joshID].Plus(stubInterpreter(), committed[joshID+firstDelegatorStringID], interpreter.EmptyLocationRange)).(interpreter.UFix64Value).String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(committed[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(staked[joshID+firstDelegatorStringID].String()), result)

	})

	t.Run("Should be able to request unstake delegated tokens from Josh, which moves them from committed to unstaked", func(t *testing.T) {

		var amountToUnstake interpreter.UFix64Value = 4000000000000
		committed[joshID+firstDelegatorStringID] = committed[joshID+firstDelegatorStringID].Minus(stubInterpreter(), amountToUnstake, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		unstaked[joshID+firstDelegatorStringID] = unstaked[joshID+firstDelegatorStringID].Plus(stubInterpreter(), amountToUnstake, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorRequestUnstakeScript(env), joshDelegatorOneAddress)
		_ = tx.AddArgument(CadenceUFix64(amountToUnstake.String()))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(committed[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64((committed[joshID].Plus(stubInterpreter(), committed[joshID+firstDelegatorStringID], interpreter.EmptyLocationRange).(interpreter.UFix64Value)).String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(committed[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(unstaked[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(request[joshID+firstDelegatorStringID].String()), result)

	})

	t.Run("Should be able to withdraw josh delegator's unstaked tokens", func(t *testing.T) {

		var amountToWithdraw interpreter.UFix64Value = 2000000000000

		unstaked[joshID+firstDelegatorStringID] = unstaked[joshID+firstDelegatorStringID].Minus(stubInterpreter(), amountToWithdraw, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorWithdrawUnstakedScript(env), joshDelegatorOneAddress)

		_ = tx.AddArgument(CadenceUFix64(amountToWithdraw.String()))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(committed[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(unstaked[joshID+firstDelegatorStringID].String()), result)

	})

	t.Run("Should be able to delegate unstaked tokens to josh", func(t *testing.T) {

		var amountToCommit interpreter.UFix64Value = 2000000000000

		unstaked[joshID+firstDelegatorStringID] = unstaked[joshID+firstDelegatorStringID].Minus(stubInterpreter(), amountToCommit, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		committed[joshID+firstDelegatorStringID] = committed[joshID+firstDelegatorStringID].Plus(stubInterpreter(), amountToCommit, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorStakeUnstakedScript(env), joshDelegatorOneAddress)

		_ = tx.AddArgument(CadenceUFix64(amountToCommit.String()))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(committed[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64("660000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(committed[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(unstaked[joshID+firstDelegatorStringID].String()), result)

	})

	t.Run("Should be able to end the staking auction, which marks admin to unstake", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndStakingScript(env), idTableAddress)

		err := tx.AddArgument(fourNodeIDDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		request[adminID] = 25000000000000

		result := executeScriptAndCheck(t, b, templates.GenerateReturnProposedTableScript(env), nil)

		idArray := result.(cadence.Array).Values
		assert.Len(t, idArray, 3)

		result = executeScriptAndCheck(t, b, templates.GenerateReturnCurrentTableScript(env), nil)

		idArray = result.(cadence.Array).Values
		assert.Len(t, idArray, 3)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(request[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(committed[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64("20000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64("580000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalTokensStakedScript(env), nil)
		assertEqual(t, CadenceUFix64("1650000.0"), result)

		assertRoleCountsEquals(t, b, env, []uint16{0, 1, 1, 0, 1})
	})

	t.Run("Should not be able to perform delegation actions when staking isn't enabled", func(t *testing.T) {

		var amount interpreter.UFix64Value = 200000000

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorStakeUnstakedScript(env), joshDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64(amount.String())
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorStakeNewScript(env), joshDelegatorOneAddress)

		tokenAmount, err = cadence.NewUFix64("100.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorRequestUnstakeScript(env), joshDelegatorOneAddress)

		tokenAmount, err = cadence.NewUFix64(amount.String())
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			true,
		)
	})

	t.Run("Should deposit money to the fees vault", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositFeesScript(env), joshDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64("100.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetFeesBalanceScript(env), nil)
		assertEqual(t, CadenceUFix64("100.0"), result)

	})

	t.Run("Should pay correct rewards, no delegators are paid because none are staked yet", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GeneratePayRewardsScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		verifyEpochTotalRewardsPaid(t, b, idTableAddress,
			EpochTotalRewardsPaid{
				total:      "1250000.0000",
				fromFees:   "100.0",
				minted:     "1249900.0000",
				feesBurned: "0.0125"})

		totalStaked = 165000000000000

		result := executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(unstaked[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(unstaked[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(staked[adminID].String()), result)

		// Update test rewards values for the admin node
		rewardsResult, _ := payRewards(false, totalPayout, totalStaked, cutPercentage, staked[adminID])
		rewards[adminID] = rewards[adminID].Plus(stubInterpreter(), rewardsResult, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(rewards[adminID].String()), result)

		// Update test rewards values for the josh node
		rewardsResult, _ = payRewards(false, totalPayout, totalStaked, cutPercentage, 0)
		rewards[joshID] = rewards[joshID].Plus(stubInterpreter(), rewardsResult, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		// Update test rewards values for the josh node delegator
		rewardsResult, delegateeRewardsResult := payRewards(true, totalPayout, totalStaked, cutPercentage, 0)
		rewards[joshID] = rewards[joshID].Plus(stubInterpreter(), delegateeRewardsResult, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		rewards[joshID+firstDelegatorStringID] = rewards[joshID+firstDelegatorStringID].Plus(stubInterpreter(), rewardsResult, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(rewards[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(rewards[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("1400000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		assertEqual(t, CadenceUFix64("1400000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("1060606.05"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(accessID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

	})

	t.Run("Should Move tokens between buckets", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateMoveTokensScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		committed[adminID], staked[adminID], request[adminID], unstaking[adminID], unstaked[adminID], totalStaked = moveTokens(
			committed[adminID], staked[adminID], request[adminID], unstaking[adminID], unstaked[adminID], totalStaked)

		committed[joshID], staked[joshID], request[joshID], unstaking[joshID], unstaked[joshID], totalStaked = moveTokens(
			committed[joshID], staked[joshID], request[joshID], unstaking[joshID], unstaked[joshID], totalStaked)

		committed[joshID+firstDelegatorStringID], staked[joshID+firstDelegatorStringID], request[joshID+firstDelegatorStringID], unstaking[joshID+firstDelegatorStringID], unstaked[joshID+firstDelegatorStringID], totalStaked = moveTokens(
			committed[joshID+firstDelegatorStringID], staked[joshID+firstDelegatorStringID], request[joshID+firstDelegatorStringID], unstaking[joshID+firstDelegatorStringID], unstaked[joshID+firstDelegatorStringID], totalStaked)

		committed[maxID], staked[maxID], request[maxID], unstaking[maxID], unstaked[maxID], totalStaked = moveTokens(
			committed[maxID], staked[maxID], request[maxID], unstaking[maxID], unstaked[maxID], totalStaked)

		committed[accessID], staked[accessID], request[accessID], unstaking[accessID], unstaked[accessID], totalStaked = moveTokens(
			committed[accessID], staked[accessID], request[accessID], unstaking[accessID], unstaked[accessID], totalStaked)

		result := executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(unstaked[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(committed[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(staked[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(request[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(unstaking[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(rewards[adminID].String()), result)

		// josh buckets

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(unstaked[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(committed[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(staked[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(request[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(unstaking[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(rewards[joshID].String()), result)

		// Josh Delegator Buckets

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(unstaked[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(committed[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(staked[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(request[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(unstaking[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(rewards[joshID+firstDelegatorStringID].String()), result)

		// Max buckets

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("1400000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("1060606.05"), result)

	})

	t.Run("Should create new execution node", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterNodeScript(env), bastianAddress)

		_ = tx.AddArgument(CadenceString(bastianID))
		_ = tx.AddArgument(cadence.NewUInt8(3))
		_ = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", bastian)))
		_ = tx.AddArgument(CadenceString(bastianNetworkingKey))
		_ = tx.AddArgument(CadenceString(bastianStakingKey))
		_ = tx.AddArgument(CadenceString(bastianStakingPOP))
		_ = tx.AddArgument(CadenceUFix64("1400000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{bastianAddress},
			[]crypto.Signer{bastianSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(bastianID))})
		assertEqual(t, CadenceUFix64("1400000.0"), result)
	})

	t.Run("Should be able to register first account to delegate to max", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterDelegatorScript(env), maxDelegatorOneAddress)

		err := tx.AddArgument(cadence.String(maxID))
		require.NoError(t, err)

		tokenAmount, _ := cadence.NewUFix64("100000.0")
		tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{maxDelegatorOneAddress},
			[]crypto.Signer{maxDelegatorOneSigner},
			false,
		)
	})

	t.Run("Should be able to register second account to delegate to max", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterDelegatorScript(env), maxDelegatorTwoAddress)

		err := tx.AddArgument(cadence.String(maxID))
		require.NoError(t, err)

		tokenAmount, _ := cadence.NewUFix64("200000.0")
		tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{maxDelegatorTwoAddress},
			[]crypto.Signer{maxDelegatorTwoSigner},
			false,
		)
	})

	t.Run("Should not be able request unstaking below the minimum if a node has delegators staked or committed", func(t *testing.T) {

		result := executeScriptAndCheck(t, b, templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64("660000.0"), result)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeTokensScript(env), joshAddress)

		err := tx.AddArgument(CadenceUFix64("180000.0"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			true,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeTokensScript(env), maxAddress)

		err = tx.AddArgument(CadenceUFix64("500000.0"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{maxAddress},
			[]crypto.Signer{maxSigner},
			true,
		)
	})

	t.Run("Should be able to commit rewarded tokens", func(t *testing.T) {

		var newCommitAmount uint64 = 50000

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStakeRewardedTokensScript(env), idTableAddress)

		err := tx.AddArgument(CadenceUFix64("50000.0"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		rewards[adminID] = rewards[adminID].Minus(stubInterpreter(), interpreter.NewUFix64ValueWithInteger(nil, func() uint64 { return newCommitAmount }, interpreter.EmptyLocationRange), interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		committed[adminID] = committed[adminID].Plus(stubInterpreter(), interpreter.NewUFix64ValueWithInteger(nil, func() uint64 { return newCommitAmount }, interpreter.EmptyLocationRange), interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		result := executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(rewards[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(committed[adminID].String()), result)
	})

	// Josh Delegator Requests to unstake which marks their request
	t.Run("Should be able to request unstake delegated tokens from Josh, marks as requested", func(t *testing.T) {

		var requestAmount interpreter.UFix64Value = 4000000000000

		request[joshID+firstDelegatorStringID] = request[joshID+firstDelegatorStringID].Plus(stubInterpreter(), requestAmount, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorRequestUnstakeScript(env), joshDelegatorOneAddress)
		_ = tx.AddArgument(CadenceUFix64(requestAmount.String()))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(committed[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64("620000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(committed[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(unstaked[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(request[joshID+firstDelegatorStringID].String()), result)

	})

	t.Run("Should be able cancel unstake request for delegator", func(t *testing.T) {

		var cancelRequestAmount interpreter.UFix64Value = 2000000000000

		request[joshID+firstDelegatorStringID] = request[joshID+firstDelegatorStringID].Minus(stubInterpreter(), cancelRequestAmount, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorStakeUnstakedScript(env), joshDelegatorOneAddress)

		err := tx.AddArgument(CadenceUFix64(cancelRequestAmount.String()))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(request[joshID+firstDelegatorStringID].String()), result)

	})

	// Josh Delegator Requests to unstake which marks their request
	t.Run("Should be able to request unstake delegated tokens from Josh, marks as requested", func(t *testing.T) {

		var requestAmount interpreter.UFix64Value = 2000000000000

		request[joshID+firstDelegatorStringID] = request[joshID+firstDelegatorStringID].Plus(stubInterpreter(), requestAmount, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorRequestUnstakeScript(env), joshDelegatorOneAddress)
		_ = tx.AddArgument(CadenceUFix64(requestAmount.String()))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(request[joshID+firstDelegatorStringID].String()), result)
	})

	fourNodeIDs[3] = bastianID
	fourNodeIDDict = generateCadenceNodeDictionary(fourNodeIDs)

	// End the staking auction
	t.Run("Should be able to end the staking auction", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndStakingScript(env), idTableAddress)

		err := tx.AddArgument(fourNodeIDDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		assertRoleCountsEquals(t, b, env, []uint16{0, 1, 2, 0, 1})

		unstaked[adminID] = unstaked[adminID].Plus(stubInterpreter(), committed[adminID], interpreter.EmptyLocationRange).(interpreter.UFix64Value)

	})

	// Move tokens between buckets. Josh delegator's should be in the unstaking bucket
	// also make sure that the total totens for the #3 node role is correct
	// Make sure that admin's unstaking were moved into their unstaked
	t.Run("Should Move tokens between buckets", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateMoveTokensScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		committed[adminID], _, request[adminID], unstaking[adminID], unstaked[adminID], totalStaked = moveTokens(
			committed[adminID], staked[adminID], request[adminID], unstaking[adminID], unstaked[adminID], totalStaked)

		committed[joshID], staked[joshID], request[joshID], unstaking[joshID], unstaked[joshID], totalStaked = moveTokens(
			committed[joshID], staked[joshID], request[joshID], unstaking[joshID], unstaked[joshID], totalStaked)

		committed[joshID+firstDelegatorStringID], staked[joshID+firstDelegatorStringID], request[joshID+firstDelegatorStringID], unstaking[joshID+firstDelegatorStringID], unstaked[joshID+firstDelegatorStringID], totalStaked = moveTokens(
			committed[joshID+firstDelegatorStringID], staked[joshID+firstDelegatorStringID], request[joshID+firstDelegatorStringID], unstaking[joshID+firstDelegatorStringID], unstaked[joshID+firstDelegatorStringID], totalStaked)

		committed[maxID], staked[maxID], request[maxID], unstaking[maxID], unstaked[maxID], totalStaked = moveTokens(
			committed[maxID], staked[maxID], request[maxID], unstaking[maxID], unstaked[maxID], totalStaked)

		committed[accessID], staked[accessID], request[accessID], unstaking[accessID], unstaked[accessID], totalStaked = moveTokens(
			committed[accessID], staked[accessID], request[accessID], unstaking[accessID], unstaked[accessID], totalStaked)

		result := executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(staked[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(unstaked[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(staked[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(staked[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(unstaking[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		assertEqual(t, CadenceUFix64("620000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("1400000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("100000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		assertEqual(t, CadenceUFix64("200000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(bastianID))})
		assertEqual(t, CadenceUFix64("1400000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		assertEqual(t, CadenceUFix64("3100000.0"), result)

		assertRoleCountsEquals(t, b, env, []uint16{0, 1, 2, 0, 1})
	})

	threeNodeIDs := fourNodeIDs[:len(fourNodeIDs)-1]
	threeNodeIDDict := generateCadenceNodeDictionary(threeNodeIDs)

	// Pay rewards and make sure josh and josh delegator got paid the right amounts based on the cut
	t.Run("Should pay correct rewards, rewards are split up properly between stakers and delegators", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDepositFeesScript(env), joshDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64("1300000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetFeesBalanceScript(env), nil)
		assertEqual(t, CadenceUFix64("1300000.0"), result)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEndStakingScript(env), idTableAddress)

		err = tx.AddArgument(threeNodeIDDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(rewards[adminID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalTokensStakedScript(env), nil)
		assertEqual(t, CadenceUFix64("3720000.0"), result)

		totalStaked = 372000000000000

		assertRoleCountsEquals(t, b, env, []uint16{0, 1, 1, 0, 1})

		tx = createTxWithTemplateAndAuthorizer(b, templates.GeneratePayRewardsScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		verifyEpochTotalRewardsPaid(t, b, idTableAddress,
			EpochTotalRewardsPaid{
				total:      "1250000.000000",
				fromFees:   "1250000.000000",
				minted:     "0.0",
				feesBurned: "50000.02"})

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assertEqual(t, CadenceUFix64(rewards[adminID].String()), result)

		rewardsResult, _ := payRewards(false, totalPayout, totalStaked, cutPercentage, staked[joshID])
		rewards[joshID] = rewards[joshID].Plus(stubInterpreter(), rewardsResult, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		rewardsResult, delegateeRewardsResult := payRewards(true, totalPayout, totalStaked, cutPercentage, staked[joshID+firstDelegatorStringID])
		rewards[joshID] = rewards[joshID].Plus(stubInterpreter(), delegateeRewardsResult, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		rewards[joshID+firstDelegatorStringID] = rewards[joshID+firstDelegatorStringID].Plus(stubInterpreter(), rewardsResult, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64(rewards[joshID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64(rewards[joshID+firstDelegatorStringID].String()), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("1539100.666"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("30913.978"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		assertEqual(t, CadenceUFix64("61827.956"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(bastianID))})
		assertEqual(t, CadenceUFix64("470430.1"), result)

	})

	// Move tokens. make sure josh delegators unstaking tokens are moved into their unstaked bucket
	t.Run("Should Move tokens between buckets", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateMoveTokensScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("40000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("40000.0"), result)

		assertRoleCountsEquals(t, b, env, []uint16{0, 1, 1, 0, 1})

	})

	// Max Delegator Withdraws rewards
	t.Run("Should be able to withdraw delegator rewards", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorWithdrawRewardsScript(env), maxDelegatorOneAddress)
		_ = tx.AddArgument(CadenceUFix64("2000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{maxDelegatorOneAddress},
			[]crypto.Signer{maxDelegatorOneSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("28913.978"), result)

	})

	t.Run("Should commit more delegator tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorStakeNewScript(env), maxDelegatorOneAddress)
		_ = tx.AddArgument(CadenceUFix64("2000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{maxDelegatorOneAddress},
			[]crypto.Signer{maxDelegatorOneSigner},
			false,
		)

	})

	t.Run("Should not be able to request unstaking for less than the minimum, even if delegators make more than the minimum", func(t *testing.T) {

		result := executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("1400000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("100000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		assertEqual(t, CadenceUFix64("200000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("2000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("1702000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalCommitmentBalanceWithoutDelegatorsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		assertEqual(t, CadenceUFix64("1400000.0"), result)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeTokensScript(env), maxAddress)

		err := tx.AddArgument(CadenceUFix64("160000.0"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{maxAddress},
			[]crypto.Signer{maxSigner},
			true,
		)
	})

	twoNodeIDs := threeNodeIDs[:len(threeNodeIDs)-1]
	twoNodeIDDict := generateCadenceNodeDictionary(twoNodeIDs)

	// End the staking auction, saying that Max is not on the approved node list
	t.Run("Should refund delegators when their node is not included in the auction", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), idTableAddress)

		err := tx.AddArgument(twoNodeIDDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("100000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("2000.0"), result)

		assertRoleCountsEquals(t, b, env, []uint16{0, 1, 0, 0, 1})

	})

	t.Run("Should be able to request unstake all which also requests to unstake all the delegator's tokens", func(t *testing.T) {

		result := executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeAllScript(env), joshAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64("580000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

	})

	t.Run("Should be able to cancel unstake request for node operator", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStakeUnstakedTokensScript(env), joshAddress)
		err := tx.AddArgument(CadenceUFix64("510000.0"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64("70000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

	})

	t.Run("Should be able to request a small unstake even if there are delegators", func(t *testing.T) {

		result := executeScriptAndCheck(t, b, templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		assertEqual(t, CadenceUFix64("500000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetTotalCommitmentBalanceWithoutDelegatorsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64("510000.0"), result)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeTokensScript(env), joshAddress)
		err := tx.AddArgument(CadenceUFix64("5.0"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		assertEqual(t, CadenceUFix64("70005.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("0.0"), result)

	})

	t.Run("Should be able request unstake all again", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeAllScript(env), joshAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)
	})

	t.Run("Should end staking auction and move tokens in the same transaction, unstaking unstakeAll delegators' tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), idTableAddress)

		err := tx.AddArgument(twoNodeIDDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		assertEqual(t, CadenceUFix64("40000.0"), result)

		assertRoleCountsEquals(t, b, env, []uint16{0, 0, 0, 0, 1})
	})

	t.Run("Should end epoch and change payout in the same transaction", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochChangePayoutScript(env), idTableAddress)

		err := tx.AddArgument(twoNodeIDDict)
		require.NoError(t, err)

		err = tx.AddArgument(CadenceUFix64("4000000.0"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		_ = executeScriptAndCheck(t, b, templates.GenerateGetNodeInfoFromAddressScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})

		_ = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorInfoFromAddressScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshDelegatorOneAddress))})

	})

	t.Run("Should be able to change the staking minimums", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateChangeMinimumsScript(env), idTableAddress)

		colMin := CadenceUFix64("250000.0")
		conMin := CadenceUFix64("250000.0")
		exMin := CadenceUFix64("1250000.0")
		verMin := CadenceUFix64("135000.0")
		accMin := CadenceUFix64("0.0")

		err := tx.AddArgument(cadence.NewArray([]cadence.Value{colMin, conMin, exMin, verMin, accMin}))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		assertEqual(t, colMin, result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		assertEqual(t, conMin, result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		assertEqual(t, exMin, result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		assertEqual(t, verMin, result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		assertEqual(t, CadenceUFix64("0.0"), result)

	})

	t.Run("Should be able to create public Capability for node", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateAddPublicNodeCapabilityScript(env), joshAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			false,
		)
	})

	t.Run("Should be able to create public Capability for delegator", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateAddPublicDelegatorCapabilityScript(env), joshDelegatorOneAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshDelegatorOneAddress},
			[]crypto.Signer{joshDelegatorOneSigner},
			false,
		)
	})

	t.Run("Should be able to remove unapproved nodes from the table without ending staking", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRemoveInvalidNodesScript(env), idTableAddress)

		err := tx.AddArgument(threeNodeIDDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

	})
}

func TestIDTableDelegatorMinimums(t *testing.T) {
	b, _, accountKeys, env := newTestSetup(t)

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	idTableAddress, _ := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, &env, true, []uint64{10, 10, 10, 10, 3})
	_, adminStakingKey, adminStakingPOP, _, adminNetworkingKey := generateKeysForNodeRegistration(t)
	mintTokensForAccount(t, b, env, idTableAddress, "1000000.0")

	// Create new user accounts and generate staking info
	delegator1Address, _, delegator1Signer := newAccountWithAddress(b, accountKeys)
	mintTokensForAccount(t, b, env, delegator1Address, "1000000.0")

	delegator2Address, _, delegator2Signer := newAccountWithAddress(b, accountKeys)
	mintTokensForAccount(t, b, env, delegator2Address, "1000000.0")

	// Register the First node
	var amountToCommit interpreter.UFix64Value = 25000000000000
	registerNode(t, b, env,
		idTableAddress,
		IDTableSigner,
		adminID,
		fmt.Sprintf("%0128d", admin),
		adminNetworkingKey,
		adminStakingKey,
		adminStakingPOP,
		amountToCommit,
		amountToCommit,
		1,
		false)

	// Register the first delegator
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterDelegatorScript(env), delegator1Address)
	tx.AddArgument(cadence.String(adminID))
	tokenAmount, _ := cadence.NewUFix64("50.0")
	tx.AddArgument(tokenAmount)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{delegator1Address},
		[]crypto.Signer{delegator1Signer},
		false,
	)

	approvedID := make([]string, 1)
	approvedID[0] = adminID
	approveIDDict := generateCadenceNodeDictionary(approvedID)

	// End Staking Auction and move tokens which marks the node and delegator's tokens as staked
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), idTableAddress)

	err := tx.AddArgument(approveIDDict)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	// Register the second delegator also with 50 FLOW
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterDelegatorScript(env), delegator2Address)
	tx.AddArgument(cadence.String(adminID))
	tx.AddArgument(tokenAmount)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{delegator2Address},
		[]crypto.Signer{delegator2Signer},
		false,
	)

	// Unstake the second delegator below the limit
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorRequestUnstakeScript(env), delegator2Address)
	tx.AddArgument(CadenceUFix64("20.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{delegator2Address},
		[]crypto.Signer{delegator2Signer},
		false,
	)

	// Unstake the first delegator below the limit
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateDelegatorRequestUnstakeScript(env), delegator1Address)
	tx.AddArgument(CadenceUFix64("25.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{delegator1Address},
		[]crypto.Signer{delegator1Signer},
		false,
	)

	// End staking auction and move tokens
	// should fully unstake both delegators since they are below the limit
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), idTableAddress)

	tx.AddArgument(approveIDDict)
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	// Make sure both delegators have unstaked tokens and all buckets reflect that
	// Delegator One
	result := executeScriptAndCheck(t, b, templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
	assertEqual(t, CadenceUFix64("0.0"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
	assertEqual(t, CadenceUFix64("0.0"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
	assertEqual(t, CadenceUFix64("0.0"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
	assertEqual(t, CadenceUFix64("50.0"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
	assertEqual(t, CadenceUFix64("0.0"), result)

	// Delegator Two
	result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
	assertEqual(t, CadenceUFix64("0.0"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
	assertEqual(t, CadenceUFix64("50.0"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
	assertEqual(t, CadenceUFix64("0.0"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
	assertEqual(t, CadenceUFix64("0.0"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
	assertEqual(t, CadenceUFix64("0.0"), result)

	// Make sure that the total staked for the node and node type reflects that too
	result = executeScriptAndCheck(t, b, templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
	assertEqual(t, CadenceUFix64("250000.0"), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
	assertEqual(t, CadenceUFix64("250000.0"), result)

	// Should be able to update the delegator minimum
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateChangeDelegatorMinimumsScript(env), idTableAddress)

	tx.AddArgument(CadenceUFix64("25.0"))
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorStakeRequirementScript(env), nil)
	assertEqual(t, CadenceUFix64("25.0"), result)

}

// TestIDTableSlotSelection tests the slot selection process for nodes which do not need to be allow-listed (Access Nodes).
//   - If the number of candidate nodes exceeds the remaining slot limit, some candidate nodes will be randomly
//     selected to be refunded and removed.
//   - If the number of participant nodes is equal to or exceeds the slot limit, no new candidates will be accepted
//     but no participants will be removed.
func TestIDTableSlotSelection(t *testing.T) {
	b, _, accountKeys, env := newTestSetup(t)

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	idTableAddress, _ := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, &env, true, []uint64{10, 10, 10, 10, 3})

	// Create new user accounts and generate staking info
	access1Address, _, access1Signer := newAccountWithAddress(b, accountKeys)
	mintTokensForAccount(t, b, env, access1Address, "1000000.0")
	_, access1StakingKey, access1StakingPOP, _, access1NetworkingKey := generateKeysForNodeRegistration(t)

	access2Address, _, access2Signer := newAccountWithAddress(b, accountKeys)
	mintTokensForAccount(t, b, env, access2Address, "1000000.0")
	_, access2StakingKey, access2StakingPOP, _, access2NetworkingKey := generateKeysForNodeRegistration(t)

	access3Address, _, access3Signer := newAccountWithAddress(b, accountKeys)
	mintTokensForAccount(t, b, env, access3Address, "1000000.0")
	_, access3StakingKey, access3StakingPOP, _, access3NetworkingKey := generateKeysForNodeRegistration(t)

	access4Address, _, access4Signer := newAccountWithAddress(b, accountKeys)
	mintTokensForAccount(t, b, env, access4Address, "1000000.0")
	_, access4StakingKey, access4StakingPOP, _, access4NetworkingKey := generateKeysForNodeRegistration(t)

	t.Run("Should be able to set new slot limits", func(t *testing.T) {
		// Set the Slot Limits to 2 for access nodes
		setNodeRoleSlotLimits(t, b, env, idTableAddress, IDTableSigner, [5]uint16{100, 100, 100, 100, 2})

		result := executeScriptAndCheck(t, b, templates.GenerateGetSlotLimitsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		assertEqual(t, cadence.NewUInt16(100), result)
		result = executeScriptAndCheck(t, b, templates.GenerateGetSlotLimitsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		assertEqual(t, cadence.NewUInt16(100), result)
		result = executeScriptAndCheck(t, b, templates.GenerateGetSlotLimitsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		assertEqual(t, cadence.NewUInt16(100), result)
		result = executeScriptAndCheck(t, b, templates.GenerateGetSlotLimitsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		assertEqual(t, cadence.NewUInt16(100), result)
		result = executeScriptAndCheck(t, b, templates.GenerateGetSlotLimitsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		assertEqual(t, cadence.NewUInt16(2), result)
	})

	var amountToCommit interpreter.UFix64Value = 10000000000000

	// Register the first access node
	registerNode(t, b, env,
		access1Address,
		access1Signer,
		adminID,
		fmt.Sprintf("%0128d", admin),
		access1NetworkingKey,
		access1StakingKey,
		access1StakingPOP,
		amountToCommit,
		amountToCommit,
		5,
		false)

	// Register the second access node
	registerNode(t, b, env,
		access2Address,
		access2Signer,
		joshID,
		fmt.Sprintf("%0128d", josh),
		access2NetworkingKey,
		access2StakingKey,
		access2StakingPOP,
		amountToCommit,
		amountToCommit,
		5,
		false)

	// Register the third access node
	registerNode(t, b, env,
		access3Address,
		access3Signer,
		maxID,
		fmt.Sprintf("%0128d", max),
		access3NetworkingKey,
		access3StakingKey,
		access3StakingPOP,
		amountToCommit,
		amountToCommit,
		5,
		false)

	noApprovalIDs := make([]string, 0)
	noApprovalIDDict := generateCadenceNodeDictionary(noApprovalIDs)

	// End the epoch, which marks the selected access nodes as staking
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), idTableAddress)
	err := tx.AddArgument(noApprovalIDDict)
	require.NoError(t, err)
	slotResult := signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	assertRoleCountsEquals(t, b, env, []uint16{0, 0, 0, 0, 2})

	var firstRemovedNodeID cadence.Value

	// see which node was removed
	for _, event := range slotResult.Events {
		if event.Type == "A.179b6b1cb6755e31.FlowIDTableStaking.NodeRemovedAndRefunded" {
			eventValue := event.Value
			firstRemovedNodeID = eventValue.Fields[0]
		}
	}

	// Current Participant Table should include two of the access nodes
	result := executeScriptAndCheck(t, b, templates.GenerateReturnCurrentTableScript(env), nil)
	idArray := result.(cadence.Array).Values
	assert.Len(t, idArray, 2)

	// Make sure that the non-removed nodes are staked
	result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(idArray[0])})
	assertEqual(t, CadenceUFix64("100000.0"), result)
	result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(idArray[1])})
	assertEqual(t, CadenceUFix64("100000.0"), result)

	// Make sure that the node that was removed was unstaked
	result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(firstRemovedNodeID)})
	assertEqual(t, CadenceUFix64("100000.0"), result)

	// Set the Slot Limits to 1 for access nodes
	// 2 nodes are already staked, which is above the limit
	// but since they are already there, they won't be removed
	setNodeRoleSlotLimits(t, b, env, idTableAddress, IDTableSigner, [5]uint16{1000, 1000, 1000, 1000, 1})

	// Register the fourth access node
	registerNode(t, b, env,
		access4Address,
		access4Signer,
		bastianID,
		fmt.Sprintf("%0128d", bastian),
		access4NetworkingKey,
		access4StakingKey,
		access4StakingPOP,
		amountToCommit,
		amountToCommit,
		5,
		false)

	// End the epoch, which should not unstake any access nodes which were already staked
	// and should unstake the fourth who tried to join
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), idTableAddress)

	err = tx.AddArgument(noApprovalIDDict)
	require.NoError(t, err)

	slotResult = signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	assertRoleCountsEquals(t, b, env, []uint16{0, 0, 0, 0, 2})

	var secondRemovedNodeID cadence.Value

	// see which node was removed
	for _, event := range slotResult.Events {
		if event.Type == "A.179b6b1cb6755e31.FlowIDTableStaking.NodeRemovedAndRefunded" {
			eventValue := event.Value
			secondRemovedNodeID = eventValue.Fields[0]
		}
	}

	// Make sure that that removed node was the one who registered
	assertEqual(t, CadenceString(bastianID), secondRemovedNodeID)

	// Make sure that the node that was removed was unstaked
	result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(secondRemovedNodeID)})
	assertEqual(t, CadenceUFix64("100000.0"), result)

	// Make sure that the non-removed nodes are still staked
	result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(idArray[0])})
	assertEqual(t, CadenceUFix64("100000.0"), result)
	result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(idArray[1])})
	assertEqual(t, CadenceUFix64("100000.0"), result)

	// Current Participant Table should include two of the access nodes
	result = executeScriptAndCheck(t, b, templates.GenerateReturnCurrentTableScript(env), nil)
	idArray = result.(cadence.Array).Values
	assert.Len(t, idArray, 2)

	// Unstake all for both access nodes that are still staked

	var stakedAddressOne flow.Address
	var stakedSignerOne crypto.Signer
	var stakedAddressTwo flow.Address
	var stakedSignerTwo crypto.Signer

	// Since selection was random, need to account for all possibilities
	if assert.ObjectsAreEqual(cadence.String(adminID), firstRemovedNodeID) {
		stakedAddressOne = access2Address
		stakedSignerOne = access2Signer
		stakedAddressTwo = access3Address
		stakedSignerTwo = access3Signer
	} else if assert.ObjectsAreEqual(cadence.String(joshID), firstRemovedNodeID) {
		stakedAddressOne = access1Address
		stakedSignerOne = access1Signer
		stakedAddressTwo = access3Address
		stakedSignerTwo = access3Signer
	} else if assert.ObjectsAreEqual(cadence.String(maxID), firstRemovedNodeID) {
		stakedAddressOne = access1Address
		stakedSignerOne = access1Signer
		stakedAddressTwo = access2Address
		stakedSignerTwo = access2Signer
	}

	t.Run("Should include a new node in a slot that was just opened from an existing node being removed", func(t *testing.T) {
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeAllScript(env), stakedAddressOne)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{stakedAddressOne},
			[]crypto.Signer{stakedSignerOne},
			false,
		)
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeAllScript(env), stakedAddressTwo)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{stakedAddressTwo},
			[]crypto.Signer{stakedSignerTwo},
			false,
		)

		// Commit more tokens for the unstaked Node

		commitUnstaked(t, b, env,
			access4Address,
			access4Signer,
			amountToCommit,
			amountToCommit,
			amountToCommit,
			false)

		result = executeScriptAndCheck(t, b, templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(bastianID))})
		assertEqual(t, CadenceUFix64("100000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(idArray[0])})
		assertEqual(t, CadenceUFix64("100000.0"), result)

		result := executeScriptAndCheck(t, b, templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(idArray[1])})
		assertEqual(t, CadenceUFix64("100000.0"), result)

		// Set open slots for access nodes to 2
		// This will make it so 2 slots are always opened up for access nodes
		// during each epoch
		setNodeRoleOpenSlots(t, b, env, idTableAddress, IDTableSigner, [5]uint16{0, 0, 0, 0, 4})

		// End the epoch, which should unstake the two who requested and stake access4
		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), idTableAddress)
		err = tx.AddArgument(noApprovalIDDict)
		require.NoError(t, err)
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		assertRoleCountsEquals(t, b, env, []uint16{0, 0, 0, 0, 1})

		// New Slot limit for access nodes should be 5 since it is 1 current node
		// plus four automatic open slots
		result = executeScriptAndCheck(t, b, templates.GenerateGetSlotLimitsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		assertEqual(t, cadence.NewUInt16(5), result)

		// Current Participant Table should include one access node
		result = executeScriptAndCheck(t, b, templates.GenerateReturnCurrentTableScript(env), nil)
		singleIdArray := result.(cadence.Array).Values
		assert.Len(t, singleIdArray, 1)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingBalanceScript(env), [][]byte{jsoncdc.MustEncode(idArray[0])})
		assertEqual(t, CadenceUFix64("100000.0"), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetUnstakingBalanceScript(env), [][]byte{jsoncdc.MustEncode(idArray[1])})
		assertEqual(t, CadenceUFix64("100000.0"), result)

		// Make sure that the node that was committed is now staked
		result = executeScriptAndCheck(t, b, templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(CadenceString(bastianID))})
		assertEqual(t, CadenceUFix64("100000.0"), result)

	})
}

func TestIDTableRewardsWitholding(t *testing.T) {

	t.Parallel()

	b, adapter := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
		BurnerAddress:        emulatorServiceAccount,
		StorageFeesAddress:   emulatorServiceAccount,
	}

	accountKeys := test.AccountKeyGenerator()

	var totalPayout interpreter.UFix64Value = 125000000000000 // 1.25M
	var cutPercentage interpreter.UFix64Value = 8000000       // 08.0 %

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	idTableAddress, feesAddr := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, &env, true, []uint64{10, 10, 10, 10, 10})

	env.IDTableAddress = idTableAddress.Hex()
	env.FlowFeesAddress = feesAddr.Hex()

	// Create records for the various staking buckets
	committed := make(map[string]interpreter.UFix64Value)
	// rewards := make(map[string]interpreter.UFix64Value)

	numNodes := 10
	numDelegators := 10

	// Create arrays for the node account information
	nodeKeys := make([]*flow.AccountKey, numNodes)
	nodeSigners := make([]crypto.Signer, numNodes)
	nodeAddresses := make([]flow.Address, numNodes)
	nodeStakingKeys := make([]string, numNodes)
	nodeStakingKeyPOPs := make([]string, numNodes)
	nodeNetworkingKeys := make([]string, numNodes)
	ids, _, _ := generateNodeIDs(numNodes)

	// Create all the node accounts
	for i := 0; i < numNodes; i++ {
		nodeKeys[i], nodeSigners[i] = accountKeys.NewWithSigner()
		nodeAddresses[i], _ = adapter.CreateAccount(context.Background(), []*flow.AccountKey{nodeKeys[i]}, nil)
		_, nodeStakingKeys[i], nodeStakingKeyPOPs[i], _, nodeNetworkingKeys[i] = generateKeysForNodeRegistration(t)
	}

	// Create arrays for the delegator account information
	delegatorKeys := make([]*flow.AccountKey, numDelegators)
	delegatorSigners := make([]crypto.Signer, numDelegators)
	delegatorAddresses := make([]flow.Address, numDelegators)

	// Create all the delegator accounts
	for i := 0; i < numDelegators; i++ {
		delegatorKeys[i], delegatorSigners[i] = accountKeys.NewWithSigner()
		delegatorAddresses[i], _ = adapter.CreateAccount(context.Background(), []*flow.AccountKey{delegatorKeys[i]}, nil)
	}

	// Each node will commit 500k FLOW
	var amountToCommit interpreter.UFix64Value = 50000000000000

	// Fund each node and register each node for staking
	for i := 0; i < numNodes; i++ {

		// Fund the node account
		mintTokensForAccount(t, b, env, nodeAddresses[i], "1000000.0")

		// Register the node
		committed[adminID] = registerNode(t, b, env,
			nodeAddresses[i],
			nodeSigners[i],
			ids[i],
			fmt.Sprintf("%0128s", ids[i]),
			nodeNetworkingKeys[i],
			nodeStakingKeys[i],
			nodeStakingKeyPOPs[i],
			amountToCommit,
			committed[ids[i]],
			1,
			false)

	}

	// Fund each delegator and register each one
	// node 0 and 1 each get 5 delegators, but the other nodes get none
	for i := 0; i < numDelegators; i++ {

		// Fund the delegator account
		mintTokensForAccount(t, b, env, delegatorAddresses[i], "1000000.0")

		// Register the delegator
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterDelegatorScript(env), delegatorAddresses[i])
		err := tx.AddArgument(cadence.String(ids[i/5]))
		require.NoError(t, err)
		_ = tx.AddArgument(CadenceUFix64("10000.0"))
		signAndSubmit(
			t, b, tx,
			[]flow.Address{delegatorAddresses[i]},
			[]crypto.Signer{delegatorSigners[i]},
			false,
		)
	}

	// Create an array of all the node IDs so they can be approved for staking
	cadenceIDs := make([]cadence.Value, numNodes)
	for i := 0; i < numNodes; i++ {
		cadenceIDs[i] = CadenceString(ids[i])
	}

	nodeIDsDict := generateCadenceNodeDictionary(ids)

	// End the epoch, which marks everyone as staking
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateEndEpochScript(env), idTableAddress)
	err := tx.AddArgument(nodeIDsDict)
	require.NoError(t, err)
	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	t.Run("Should be able to set multiple nodes as inactive so their rewards will be withheld", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetNonOperationalScript(env), idTableAddress)
		err := tx.AddArgument(cadence.NewArray([]cadence.Value{CadenceString(ids[0]), CadenceString(ids[2])}))
		require.NoError(t, err)
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetNonOperationalListScript(env), nil)
		idArray := result.(cadence.Array).Values
		assert.Equal(t, len(idArray), 2)
		assert.ElementsMatch(t, idArray, cadence.NewArray([]cadence.Value{CadenceString(ids[0]), CadenceString(ids[2])}).Values)
	})

	t.Run("Should pay rewards, but rewards from bad nodes and delegators are re-distributed", func(t *testing.T) {

		// Pay Rewards
		tx := createTxWithTemplateAndAuthorizer(b, templates.GeneratePayRewardsScript(env), idTableAddress)
		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

		verifyEpochTotalRewardsPaid(t, b, idTableAddress,
			EpochTotalRewardsPaid{
				total:      "1250000.0000",
				fromFees:   "0.0",
				minted:     "1250000.0000",
				feesBurned: "0.06200000"})

		result := executeScriptAndCheck(t, b, templates.GenerateGetNonOperationalListScript(env), nil)

		idArray := result.(cadence.Array).Values
		assert.Equal(t, len(idArray), 0)

		// Check Rewards balances of nodes and delegators who were withheld
		// to make sure they got zero

		// Node 0
		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[0]))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		// Node 2
		result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[2]))})
		assertEqual(t, CadenceUFix64("0.0"), result)

		// Delegators from Node 0
		for i := 1; i < 6; i++ {
			result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[0])), jsoncdc.MustEncode(cadence.UInt32(i))})
			assertEqual(t, CadenceUFix64("0.0"), result)
		}

		// Check rewards balances of the other nodes and delegators to make sure
		// the extra rewards were distributed to them

		// Calculate Rewards
		// All the nodes staked 500k FLOW and all the delegators staked 10k FLOW
		// so the calculations are slightly easier
		// Node 0 has 5 delegators, node 1 has 5 delegators,
		// and the other nodes have no delegators
		// Tested witholding rewards from one of the nodes with delegators
		// and one of the non-delegated-to nodes

		// The amount of tokens each delegator committed (10k FLOW)
		var delegatorCommitment interpreter.UFix64Value = 1000000000000
		// The total number of delegators = 10
		var numDelegators interpreter.UFix64Value = 1000000000
		// For multiplying the token amounts (5 nodes for node 0)
		var numDelegatorsForNode0 interpreter.UFix64Value = 500000000
		// 10 Nodes total
		var numNodesTotal interpreter.UFix64Value = 1000000000

		// Number of Nodes whose rewards have been withheld (For multiplying the token amounts)
		var numWithheldNodes interpreter.UFix64Value = 200000000

		var totalStaked interpreter.UFix64Value = delegatorCommitment.Mul(stubInterpreter(), numDelegators, interpreter.EmptyLocationRange).Plus(stubInterpreter(), amountToCommit.Mul(stubInterpreter(), numNodesTotal, interpreter.EmptyLocationRange), interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		var totalStakedFromNonOperationalStakers interpreter.UFix64Value = delegatorCommitment.Mul(stubInterpreter(), numDelegatorsForNode0, interpreter.EmptyLocationRange).Plus(stubInterpreter(), amountToCommit.Mul(stubInterpreter(), numWithheldNodes, interpreter.EmptyLocationRange), interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		// First calculate the node and delegator rewards assuming no withholding
		nodeRewardWithoutWithold := totalPayout.Div(stubInterpreter(), totalStaked, interpreter.EmptyLocationRange).Mul(stubInterpreter(), amountToCommit, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		delegatorReward := totalPayout.Div(stubInterpreter(), totalStaked, interpreter.EmptyLocationRange).Mul(stubInterpreter(), delegatorCommitment, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		delegatorRewardNodeCut := delegatorReward.Mul(stubInterpreter(), cutPercentage, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		delegatorRewardMinusNode := delegatorReward.Minus(stubInterpreter(), delegatorRewardNodeCut, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		// The rewards for a node and its 5 delegators
		// without including withheld rewards from other nodes
		nodeRewardPlusDelegators := nodeRewardWithoutWithold.Plus(stubInterpreter(), delegatorRewardNodeCut.Mul(stubInterpreter(), numDelegatorsForNode0, interpreter.EmptyLocationRange), interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		// Figure out the sum of tokens withheld from all punished nodes
		amountWithheld := nodeRewardWithoutWithold.Mul(stubInterpreter(), numWithheldNodes, interpreter.EmptyLocationRange).Plus(stubInterpreter(), delegatorReward.Mul(stubInterpreter(), numDelegatorsForNode0, interpreter.EmptyLocationRange), interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		// Calculate the additional tokens to give to nodes and delegators
		// only from the withheld tokens
		nodeRewardFromWithheld := amountWithheld.Div(stubInterpreter(), totalStaked.Minus(stubInterpreter(), totalStakedFromNonOperationalStakers, interpreter.EmptyLocationRange), interpreter.EmptyLocationRange).Mul(stubInterpreter(), amountToCommit, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		delegatorRewardFromWithheld := amountWithheld.Div(stubInterpreter(), totalStaked.Minus(stubInterpreter(), totalStakedFromNonOperationalStakers, interpreter.EmptyLocationRange), interpreter.EmptyLocationRange).Mul(stubInterpreter(), delegatorCommitment, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		delegatorRewardNodeCutFromWithheld := delegatorRewardFromWithheld.Mul(stubInterpreter(), cutPercentage, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		delegatorRewardMinusNodeFromWithheld := delegatorRewardFromWithheld.Minus(stubInterpreter(), delegatorRewardNodeCutFromWithheld, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		// Add the normal rewards to the rewards from withholding
		totalNodeReward := nodeRewardWithoutWithold.Plus(stubInterpreter(), nodeRewardFromWithheld, interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		totalNodeRewardPlusDelegators := nodeRewardPlusDelegators.Plus(stubInterpreter(), nodeRewardFromWithheld.Plus(stubInterpreter(), delegatorRewardNodeCutFromWithheld.Mul(stubInterpreter(), numDelegatorsForNode0, interpreter.EmptyLocationRange), interpreter.EmptyLocationRange), interpreter.EmptyLocationRange).(interpreter.UFix64Value)
		totalDelegatorReward := delegatorRewardMinusNode.Plus(stubInterpreter(), delegatorRewardMinusNodeFromWithheld, interpreter.EmptyLocationRange).(interpreter.UFix64Value)

		// Nodes 1, 3-9
		for i := 1; i < numNodes; i++ {
			if i == 1 {
				result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[i]))})
				assertEqual(t, CadenceUFix64(totalNodeRewardPlusDelegators.String()), result)
			} else if i != 2 {
				result = executeScriptAndCheck(t, b, templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[i]))})
				assertEqual(t, CadenceUFix64(totalNodeReward.String()), result)
			}
		}

		// Delegators from Node 1
		for i := 1; i < 6; i++ {
			result = executeScriptAndCheck(t, b, templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(ids[1])), jsoncdc.MustEncode(cadence.UInt32(i))})
			assertEqual(t, CadenceUFix64(totalDelegatorReward.String()), result)
		}
	})
}
