package test

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"

	ft_templates "github.com/onflow/flow-ft/lib/go/templates"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

const (
	adminID   = "0000000000000000000000000000000000000000000000000000000000000001"
	admin     = 1
	joshID    = "0000000000000000000000000000000000000000000000000000000000000002"
	josh      = 2
	maxID     = "0000000000000000000000000000000000000000000000000000000000000003"
	max       = 3
	bastianID = "0000000000000000000000000000000000000000000000000000000000000004"
	bastian   = 4
	accessID  = "0000000000000000000000000000000000000000000000000000000000000005"
	access    = 5

	nonexistantID = "0000000000000000000000000000000000000000000000000000000000383838383"

	firstDelegatorID  = 1
	secondDelegatorID = 2

	emulatorFTAddress        = "ee82856bf20e2aa6"
	emulatorFlowTokenAddress = "0ae53cb6e3f42a79"
)

func TestIDTable(t *testing.T) {
	b := newEmulator()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
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
		AddRawArgument(jsoncdc.MustEncode(cadence.NewString("FlowIDTableStaking"))).
		AddRawArgument(jsoncdc.MustEncode(cadenceCode))

	_ = tx.AddArgument(CadenceUFix64("1250000.0"))
	_ = tx.AddArgument(CadenceUFix64("0.08"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{b.ServiceKey().Signer()},
		false,
	)

	var idTableAddress flow.Address

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := b.GetEventsByHeight(i, "flow.AccountCreated")

		for _, event := range results {
			if event.Type == flow.EventAccountCreated {
				idTableAddress = flow.Address(event.Value.Fields[0].(cadence.Address))
			}
		}

		i = i + 1
	}

	env.IDTableAddress = idTableAddress.Hex()

	t.Run("Should be able to read empty table fields and initialized fields", func(t *testing.T) {

		result, err := b.ExecuteScript(templates.GenerateReturnCurrentTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
			return
		}
		currentIDs := result.Value
		idArray := currentIDs.(cadence.Array).Values
		assert.Empty(t, idArray)

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Empty(t, idArray)

		// Check that the stake requirements for each node role are initialized correctly

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement := result.Value
		assertEqual(t, CadenceUFix64("250000.0"), requirement)

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement = result.Value
		assertEqual(t, CadenceUFix64("500000.0"), requirement)

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement = result.Value
		assertEqual(t, CadenceUFix64("1250000.0"), requirement)

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement = result.Value
		assertEqual(t, CadenceUFix64("135000.0"), requirement)

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement = result.Value
		assertEqual(t, CadenceUFix64("0.0"), requirement)

		// Check that the total tokens staked for each node role are initialized correctly

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens := result.Value
		assertEqual(t, CadenceUFix64("0.0"), tokens)

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens = result.Value
		assertEqual(t, CadenceUFix64("0.0"), tokens)

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens = result.Value
		assertEqual(t, CadenceUFix64("0.0"), tokens)

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens = result.Value
		assertEqual(t, CadenceUFix64("0.0"), tokens)

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens = result.Value
		assertEqual(t, CadenceUFix64("0.0"), tokens)

		// Check that the reward ratios were initialized correctly for each node role

		result, err = b.ExecuteScript(templates.GenerateGetRewardRatioScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		ratio := result.Value
		assertEqual(t, CadenceUFix64("0.168"), ratio)

		result, err = b.ExecuteScript(templates.GenerateGetRewardRatioScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		ratio = result.Value
		assertEqual(t, CadenceUFix64("0.518"), ratio)

		result, err = b.ExecuteScript(templates.GenerateGetRewardRatioScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		ratio = result.Value
		assertEqual(t, CadenceUFix64("0.078"), ratio)

		result, err = b.ExecuteScript(templates.GenerateGetRewardRatioScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		ratio = result.Value
		assertEqual(t, CadenceUFix64("0.236"), ratio)

		result, err = b.ExecuteScript(templates.GenerateGetRewardRatioScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		ratio = result.Value
		assertEqual(t, CadenceUFix64("0.0"), ratio)

		// Check that the weekly payout was initialized correctly

		result, err = b.ExecuteScript(templates.GenerateGetWeeklyPayoutScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		payout := result.Value
		assertEqual(t, CadenceUFix64("1250000.0"), payout)

	})

	// Create new user accounts
	joshAccountKey, joshSigner := accountKeys.NewWithSigner()
	joshAddress, _ := b.CreateAccount([]*flow.AccountKey{joshAccountKey}, nil)

	// Create a new user account
	maxAccountKey, maxSigner := accountKeys.NewWithSigner()
	maxAddress, _ := b.CreateAccount([]*flow.AccountKey{maxAccountKey}, nil)

	// Create a new user account
	bastianAccountKey, bastianSigner := accountKeys.NewWithSigner()
	bastianAddress, _ := b.CreateAccount([]*flow.AccountKey{bastianAccountKey}, nil)

	// Create a new user account for access node
	accessAccountKey, accessSigner := accountKeys.NewWithSigner()
	accessAddress, _ := b.CreateAccount([]*flow.AccountKey{accessAccountKey}, nil)

	// Create new delegator user accounts
	adminDelegatorAccountKey, adminDelegatorSigner := accountKeys.NewWithSigner()
	adminDelegatorAddress, _ := b.CreateAccount([]*flow.AccountKey{adminDelegatorAccountKey}, nil)

	joshDelegatorOneAccountKey, joshDelegatorOneSigner := accountKeys.NewWithSigner()
	joshDelegatorOneAddress, _ := b.CreateAccount([]*flow.AccountKey{joshDelegatorOneAccountKey}, nil)

	maxDelegatorOneAccountKey, maxDelegatorOneSigner := accountKeys.NewWithSigner()
	maxDelegatorOneAddress, _ := b.CreateAccount([]*flow.AccountKey{maxDelegatorOneAccountKey}, nil)

	maxDelegatorTwoAccountKey, maxDelegatorTwoSigner := accountKeys.NewWithSigner()
	maxDelegatorTwoAddress, _ := b.CreateAccount([]*flow.AccountKey{maxDelegatorTwoAccountKey}, nil)

	t.Run("Should be able to mint tokens for new accounts", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(idTableAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(joshAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(maxAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(accessAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		result, err := b.ExecuteScript(ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("1000000000.0"), balance)

		tx = flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(bastianAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(maxDelegatorOneAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(maxDelegatorTwoAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(joshDelegatorOneAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(adminDelegatorAddress))
		_ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)

	})

	t.Run("Shouldn't be able to create invalid Node structs", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		// Invalid ID: Too short
		_ = tx.AddArgument(cadence.NewString("3039"))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", admin)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", admin)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", admin)))
		tokenAmount, err := cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(cadence.NewString(adminID))
		// Invalid Role: Greater than 5
		_ = tx.AddArgument(cadence.NewUInt8(6))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", admin)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", admin)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", admin)))
		tokenAmount, err = cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(cadence.NewString(adminID))
		// Invalid Role: Less than 1
		_ = tx.AddArgument(cadence.NewUInt8(0))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", admin)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", admin)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", admin)))
		tokenAmount, err = cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(cadence.NewString(adminID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		// Invalid Networking Address: Length cannot be zero
		_ = tx.AddArgument(cadence.NewString(""))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", admin)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", admin)))
		tokenAmount, err = cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

	})

	t.Run("Should be able to create a valid Node struct", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		err := tx.AddArgument(cadence.NewString(adminID))
		require.NoError(t, err)
		err = tx.AddArgument(cadence.NewUInt8(1))
		require.NoError(t, err)
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", admin)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", admin)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", admin)))
		tokenAmount, err := cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateReturnTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray := proposedIDs.(cadence.Array).Values
		assert.Len(t, idArray, 1)

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs = result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Len(t, idArray, 1)

		result, err = b.ExecuteScript(templates.GenerateGetRoleScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		role := result.Value
		assertEqual(t, cadence.NewUInt8(1), role)

		result, err = b.ExecuteScript(templates.GenerateGetNetworkingAddressScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		addr := result.Value
		assertEqual(t, cadence.NewString(fmt.Sprintf("%0128d", admin)), addr)

		result, err = b.ExecuteScript(templates.GenerateGetNetworkingKeyScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		key := result.Value
		assertEqual(t, cadence.NewString(fmt.Sprintf("%0128d", admin)), key)

		result, err = b.ExecuteScript(templates.GenerateGetStakingKeyScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		key = result.Value
		assertEqual(t, cadence.NewString(fmt.Sprintf("%0192d", admin)), key)

		result, err = b.ExecuteScript(templates.GenerateGetInitialWeightScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		weight := result.Value
		assertEqual(t, cadence.NewUInt64(0), weight)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("250000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

	})

	t.Run("Shouldn't be able to create Node with a duplicate id", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		// Invalid: This ID has already been used
		_ = tx.AddArgument(cadence.NewString(adminID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", josh)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", josh)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", josh)))
		tokenAmount, err := cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)
	})

	t.Run("Shouldn't be able to create Nodes with duplicate fields", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		// Invalid: first admin networking address is already in use
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", admin)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", josh)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", josh)))
		tokenAmount, err := cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", josh)))
		// Invalid: first admin networking key is already in use
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", admin)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", josh)))
		tokenAmount, err = cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", josh)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", josh)))
		// Invalid: first admin stake key is already in use
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", admin)))
		tokenAmount, err = cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)
	})

	t.Run("Should be able to create more valid Node structs", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", josh)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", josh)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", josh)))
		tokenAmount, err := cadence.NewUFix64("480000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("480000.0"), balance)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		_ = tx.AddArgument(cadence.NewString(maxID))
		_ = tx.AddArgument(cadence.NewUInt8(3))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", max)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", max)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", max)))
		tokenAmount, err = cadence.NewUFix64("1350000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(accessAddress)

		_ = tx.AddArgument(cadence.NewString(accessID))
		_ = tx.AddArgument(cadence.NewUInt8(5))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", access)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", access)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", access)))
		tokenAmount, err = cadence.NewUFix64("50000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, accessAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), accessSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateReturnCurrentTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		currentIDs := result.Value
		idArray := currentIDs.(cadence.Array).Values
		assert.Len(t, idArray, 0)

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Len(t, idArray, 3)
	})

	t.Run("Shouldn't be able to remove a Node that doesn't exist", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRemoveNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(cadence.NewString(nonexistantID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)
	})

	t.Run("Should be able to remove a Node from the proposed record and add it back", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRemoveNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateReturnCurrentTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		currentIDs := result.Value
		idArray := currentIDs.(cadence.Array).Values
		assert.Len(t, idArray, 0)

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Len(t, idArray, 3)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", josh)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", josh)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", josh)))
		tokenAmount, err := cadence.NewUFix64("480000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs = result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Len(t, idArray, 3)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("480000.0"), balance)
	})

	t.Run("Shouldn't be able to change the cut percentage above 1", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateChangeCutScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(CadenceUFix64("2.10"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)
	})

	t.Run("Should be able to change the cut percentage", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateChangeCutScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(CadenceUFix64("0.10"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetCutPercentageScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		cut := result.Value
		assertEqual(t, CadenceUFix64("0.10"), cut)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateChangeCutScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(CadenceUFix64("0.08"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateGetCutPercentageScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		cut = result.Value
		assertEqual(t, CadenceUFix64("0.08"), cut)
	})

	t.Run("Should be able to change the weekly payout", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateChangePayoutScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(CadenceUFix64("5000000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetWeeklyPayoutScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		cut := result.Value
		assertEqual(t, CadenceUFix64("5000000.0"), cut)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateChangePayoutScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		_ = tx.AddArgument(CadenceUFix64("1250000.0"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateGetWeeklyPayoutScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		cut = result.Value
		assertEqual(t, CadenceUFix64("1250000.0"), cut)
	})

	t.Run("Should be able to commit additional tokens for a node", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateStakeNewTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		tokenAmount, err := cadence.NewUFix64("100000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("1450000.0"), balance)
	})

	t.Run("Should not be able request unstaking for more than is available", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		tokenAmount, err := cadence.NewUFix64("5000000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			true,
		)
	})

	t.Run("Should be able to request unstaking which moves from comitted to unstaked", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		tokenAmount, err := cadence.NewUFix64("100000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("1350000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("100000.0"), balance)
	})

	t.Run("Should be able to withdraw tokens from unstaked", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateWithdrawUnstakedTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		tokenAmount, err := cadence.NewUFix64("50000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("50000.0"), balance)
	})

	t.Run("Should be able to commit unstaked tokens", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateStakeUnstakedTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		tokenAmount, err := cadence.NewUFix64("50000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1400000.0"), balance)
	})

	t.Run("Should be able to end the staking auction, which removes insufficiently staked nodes", func(t *testing.T) {

		result, err := b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("480000.0"), balance)

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndStakingScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		err = tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID), cadence.NewString(maxID), cadence.NewString(accessID)}))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray := proposedIDs.(cadence.Array).Values
		assert.Len(t, idArray, 3)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("250000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("480000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1400000.0"), balance)

	})

	t.Run("Should pay rewards, but no balances are increased because nobody is staked", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GeneratePayRewardsScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("480000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(accessID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

	})

	t.Run("Should Move committed tokens to staked buckets", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateMoveTokensScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("480000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("250000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1400000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(accessID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("50000.0"), balance)

	})

	t.Run("Should be able to commit unstaked and new tokens from the node who was not included", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateStakeUnstakedTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("480000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateStakeNewTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err = cadence.NewUFix64("100000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateReturnProposedTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray := proposedIDs.(cadence.Array).Values
		assert.Len(t, idArray, 4)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("580000.0"), balance)
	})

	t.Run("Should be able to request unstaking from a staked node", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		tokenAmount, err := cadence.NewUFix64("50000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("50000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("250000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("200000.0"), balance)

		// josh, max, and access are proposed
		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray := proposedIDs.(cadence.Array).Values
		assert.Len(t, idArray, 3)

		// admin, max, and access are staked
		result, err = b.ExecuteScript(templates.GenerateReturnCurrentTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		currentIDs := result.Value
		idArray = currentIDs.(cadence.Array).Values
		assert.Len(t, idArray, 3)
	})

	/************* Start of Delegation Tests *******************/

	t.Run("Should be able to register first account to delegate to max", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterDelegatorScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxDelegatorOneAddress)

		err := tx.AddArgument(cadence.String(maxID))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxDelegatorOneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxDelegatorOneSigner},
			false,
		)
	})

	t.Run("Should be able to register second account to delegate to max", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterDelegatorScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxDelegatorTwoAddress)

		err := tx.AddArgument(cadence.String(maxID))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxDelegatorTwoAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxDelegatorTwoSigner},
			false,
		)
	})

	t.Run("Should be able to register account to delegate to josh", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterDelegatorScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshDelegatorOneAddress)

		err := tx.AddArgument(cadence.String(joshID))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshDelegatorOneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshDelegatorOneSigner},
			false,
		)
	})

	t.Run("Should not be able to register account to delegate to the admin address, because it has insufficient stake committed", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterDelegatorScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminDelegatorAddress)

		err := tx.AddArgument(cadence.String(adminID))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminDelegatorAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminDelegatorSigner},
			true,
		)
	})

	t.Run("Should not be able to register account to delegate to the access node, because access nodes are not allowed to be delegated to", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterDelegatorScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(adminDelegatorAddress)

		err := tx.AddArgument(cadence.String(accessID))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, adminDelegatorAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), adminDelegatorSigner},
			true,
		)
	})

	t.Run("Should be able to delegate new tokens to josh", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorStakeNewScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64("100000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshDelegatorOneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshDelegatorOneSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("580000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("680000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("100000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

	})

	t.Run("Should be able to request unstake delegated tokens from Josh, which moved them from committed to unstaked", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorRequestUnstakeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64("40000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshDelegatorOneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshDelegatorOneSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("580000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("640000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("60000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("40000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

	})

	t.Run("Should be able to withdraw josh delegator's unstaked tokens", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorWithdrawUnstakedScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64("20000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshDelegatorOneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshDelegatorOneSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("60000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("20000.0"), balance)

	})

	t.Run("Should be able to delegate unstaked tokens to josh", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorStakeUnstakedScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64("20000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshDelegatorOneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshDelegatorOneSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("580000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("660000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("80000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

	})

	t.Run("Should be able to end the staking auction, which marks admin to unstake", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndStakingScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		err := tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID), cadence.NewString(maxID), cadence.NewString(accessID)}))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateReturnProposedTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray := proposedIDs.(cadence.Array).Values
		assert.Len(t, idArray, 3)

		result, err = b.ExecuteScript(templates.GenerateReturnCurrentTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		currentIDs := result.Value
		idArray = currentIDs.(cadence.Array).Values
		assert.Len(t, idArray, 3)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("250000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("580000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1650000.0"), balance)
	})

	t.Run("Should pay correct rewards, no delegators are paid because none are staked yet", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GeneratePayRewardsScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("250000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("187500.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1400000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens := result.Value
		assertEqual(t, CadenceUFix64("1400000.0"), tokens)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1050000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(accessID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

	})

	t.Run("Should Move tokens between buckets", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateMoveTokensScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		// Admin buckets

		result, err := b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("250000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("187500.0"), balance)

		// josh buckets

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("580000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		// Josh Delegator Buckets

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("80000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		// Max buckets

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1400000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1050000.0"), balance)

		// Max Delegator Buckets

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

	})

	t.Run("Should create new execution node", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterNodeScript(env)).
			SetGasLimit(200).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(bastianAddress)

		_ = tx.AddArgument(cadence.NewString(bastianID))
		_ = tx.AddArgument(cadence.NewUInt8(3))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", bastian)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0128d", bastian)))
		_ = tx.AddArgument(cadence.NewString(fmt.Sprintf("%0192d", bastian)))
		tokenAmount, err := cadence.NewUFix64("1400000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, bastianAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), bastianSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(bastianID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("1400000.0"), balance)
	})

	t.Run("Should be able to delegate new tokens to max", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorStakeNewScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64("100000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxDelegatorOneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxDelegatorOneSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorStakeNewScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxDelegatorTwoAddress)

		tokenAmount, err = cadence.NewUFix64("200000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxDelegatorTwoAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxDelegatorTwoSigner},
			false,
		)

	})

	t.Run("Should not be able request unstaking below the minimum if a node has delegators staked or committed", func(t *testing.T) {

		result, err := b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("660000.0"), balance)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("180000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		tokenAmount, err = cadence.NewUFix64("500000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			true,
		)
	})

	t.Run("Should be able to commit rewarded tokens", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateStakeRewardedTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		tokenAmount, err := cadence.NewUFix64("50000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("137500.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("50000.0"), balance)
	})

	// Josh Delegator Requests to unstake which marks their request
	t.Run("Should be able to request unstake delegated tokens from Josh, marks as requested", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorRequestUnstakeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64("40000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshDelegatorOneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshDelegatorOneSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("620000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("40000.0"), balance)

	})

	t.Run("Should be able cancel unstake request for delegator", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorStakeUnstakedScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64("20000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshDelegatorOneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshDelegatorOneSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("20000.0"), balance)

	})

	// Josh Delegator Requests to unstake which marks their request
	t.Run("Should be able to request unstake delegated tokens from Josh, marks as requested", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorRequestUnstakeScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64("20000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshDelegatorOneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshDelegatorOneSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("40000.0"), balance)
	})

	// End the staking auction
	t.Run("Should be able to end the staking auction", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndStakingScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		err := tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID), cadence.NewString(maxID), cadence.NewString(bastianID)}))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

	})

	// Move tokens between buckets. Josh delegator's should be in the unstaking bucket
	// also make sure that the total totens for the #3 node role is correct
	// Make sure that admin's unstaking were moved into their unstaked
	t.Run("Should Move tokens between buckets", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateMoveTokensScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("300000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("580000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("40000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("40000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("620000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1400000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("100000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("200000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(bastianID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1400000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("3100000.0"), balance)

	})

	// Pay rewards and make sure josh and josh delegator got paid the right amounts based on the cut
	t.Run("Should pay correct rewards, rewards are split up properly between stakers and delegators", func(t *testing.T) {

		result, err := b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("137500.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1050000.0"), balance)

		tx := flow.NewTransaction().
			SetScript(templates.GeneratePayRewardsScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("137500.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("189540.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("11960.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1512800.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("29900.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("59800.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(bastianID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("455000.0"), balance)

	})

	// Move tokens. make sure josh delegators unstaking tokens are moved into their unstaked bucket
	t.Run("Should Move tokens between buckets", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateMoveTokensScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("40000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("40000.0"), balance)

	})

	// Max Delegator Withdraws rewards
	t.Run("Should be able to withdraw delegator rewards", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorWithdrawRewardsScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64("2000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxDelegatorOneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxDelegatorOneSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("27900.0"), balance)

	})

	t.Run("Should commit more delegator tokens", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorStakeNewScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64("2000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxDelegatorOneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxDelegatorOneSigner},
			false,
		)

	})

	t.Run("Should not be able request unstaking for less than the minimum, even if delegators make more than the minimum", func(t *testing.T) {

		result, err := b.ExecuteScript(templates.GenerateGetStakedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("1400000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("100000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("200000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("2000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1702000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceWithoutDelegatorsScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("1400000.0"), balance)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		tokenAmount, err := cadence.NewUFix64("160000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			true,
		)
	})

	// End the staking auction, saying that Max is not on the approved node list
	t.Run("Should refund delegators when their node is not included in the auction", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndStakingScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		err := tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID)}))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDelegatorUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("100000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("2000.0"), balance)

	})

	// End staking auction and move tokens in the same transaction
	t.Run("Should end staking auction and move tokens in the same transaction", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndEpochScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		err := tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID)}))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

	})

	t.Run("Should be able request unstake all which also requests to unstake all the delegator's tokens", func(t *testing.T) {

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeAllScript(env)).
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

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("580000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

	})

	t.Run("Should be able cancel unstake request for node operator", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateStakeUnstakedTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("180000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("400000.0"), balance)

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRequestScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assertEqual(t, CadenceUFix64("0.0"), balance)

	})

	t.Run("Should be able request unstake all again", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeAllScript(env)).
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

	t.Run("Should end staking auction and move tokens in the same transaction, unstaking unstakeAll delegators' tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndEpochScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		err := tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID)}))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDelegatorUnstakingScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assertEqual(t, CadenceUFix64("40000.0"), balance)
	})

	t.Run("Should end epoch and change payout in the same transaction", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndEpochChangePayoutScript(env)).
			SetGasLimit(9999).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		err := tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID)}))
		require.NoError(t, err)

		tokenAmount, err := cadence.NewUFix64("4000000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetNodeInfoFromAddressScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorInfoFromAddressScript(env), [][]byte{jsoncdc.MustEncode(cadence.Address(joshDelegatorOneAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}

	})

	t.Run("Should be able to change the staking minimums", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateChangeMinimumsScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		colMin, err := cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		conMin, err := cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		exMin, err := cadence.NewUFix64("1250000.0")
		require.NoError(t, err)
		verMin, err := cadence.NewUFix64("135000.0")
		require.NoError(t, err)
		accMin, err := cadence.NewUFix64("0.0")
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray([]cadence.Value{colMin, conMin, exMin, verMin, accMin}))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		assertEqual(t, colMin, result.Value)

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		assertEqual(t, conMin, result.Value)

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		assertEqual(t, exMin, result.Value)

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		assertEqual(t, verMin, result.Value)

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(env), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement := result.Value
		assertEqual(t, CadenceUFix64("0.0"), requirement)

	})
}
