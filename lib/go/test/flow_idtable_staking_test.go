package test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-go-sdk"
	sdk "github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"

	ft_templates "github.com/onflow/flow-ft/lib/go/templates"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

const (
	adminID   = "0000000000000000000000000000000000000000000000000000000000000001"
	joshID    = "0000000000000000000000000000000000000000000000000000000000000002"
	maxID     = "0000000000000000000000000000000000000000000000000000000000000003"
	bastianID = "0000000000000000000000000000000000000000000000000000000000000004"

	nonexistantID = "0000000000000000000000000000000000000000000000000000000000383838383"

	firstDelegatorID  = 1
	secondDelegatorID = 2

	emulatorFTAddress        = "ee82856bf20e2aa6"
	emulatorFlowTokenAddress = "0ae53cb6e3f42a79"
)

func TestIDTable(t *testing.T) {
	b := newEmulator()

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

	t.Run("Should be able to read empty table fields and initialized fields", func(t *testing.T) {

		result, err := b.ExecuteScript(templates.GenerateReturnCurrentTableScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		currentIDs := result.Value
		idArray := currentIDs.(cadence.Array).Values
		assert.Equal(t, 0, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Equal(t, 0, len(idArray))

		/// Check that the stake requirements for each node role are initialized correctly

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement := result.Value
		assert.Equal(t, CadenceUFix64("250000.0"), requirement.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement = result.Value
		assert.Equal(t, CadenceUFix64("500000.0"), requirement.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement = result.Value
		assert.Equal(t, CadenceUFix64("1250000.0"), requirement.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement = result.Value
		assert.Equal(t, CadenceUFix64("135000.0"), requirement.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), requirement.(cadence.UFix64))

		/// Check that the total tokens staked for each node role are initialized correctly

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), tokens.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), tokens.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), tokens.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), tokens.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), tokens.(cadence.UFix64))

		/// Check that the reward ratios were initialized correctly for each node role

		result, err = b.ExecuteScript(templates.GenerateGetRewardRatioScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		ratio := result.Value
		assert.Equal(t, CadenceUFix64("0.168"), ratio.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardRatioScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		ratio = result.Value
		assert.Equal(t, CadenceUFix64("0.518"), ratio.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardRatioScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		ratio = result.Value
		assert.Equal(t, CadenceUFix64("0.078"), ratio.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardRatioScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		ratio = result.Value
		assert.Equal(t, CadenceUFix64("0.236"), ratio.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardRatioScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		ratio = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), ratio.(cadence.UFix64))

		/// Check that the weekly payout was initialized correctly

		result, err = b.ExecuteScript(templates.GenerateGetWeeklyPayoutScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		payout := result.Value
		assert.Equal(t, CadenceUFix64("5000000.0"), payout.(cadence.UFix64))

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
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(IDTableAddr))
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
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		result, err := b.ExecuteScript(ft_templates.GenerateInspectVaultScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("1000000000.0"), balance.(cadence.UFix64))

		tx = flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		// Invalid ID: Too short
		_ = tx.AddArgument(cadence.NewString("3039"))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("12234"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err := cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(adminID))
		// Invalid Role: Greater than 5
		_ = tx.AddArgument(cadence.NewUInt8(6))
		_ = tx.AddArgument(cadence.NewString("12234"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err = cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(adminID))
		// Invalid Role: Less than 1
		_ = tx.AddArgument(cadence.NewUInt8(0))
		_ = tx.AddArgument(cadence.NewString("12234"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err = cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(adminID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		// Invalid Networking Address: Length cannot be zero
		_ = tx.AddArgument(cadence.NewString(""))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err = cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

	})

	t.Run("Should be able to create a valid Node struct", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		err := tx.AddArgument(cadence.NewString(adminID))
		require.NoError(t, err)
		err = tx.AddArgument(cadence.NewUInt8(1))
		require.NoError(t, err)
		err = tx.AddArgument(cadence.NewString("netaddress"))
		require.NoError(t, err)
		err = tx.AddArgument(cadence.NewString("netkey"))
		require.NoError(t, err)
		err = tx.AddArgument(cadence.NewString("stakekey"))
		require.NoError(t, err)
		tokenAmount, err := cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateReturnTableScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray := proposedIDs.(cadence.Array).Values
		assert.Equal(t, 1, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs = result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Equal(t, 1, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateGetRoleScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		role := result.Value
		assert.Equal(t, role.(cadence.UInt8), cadence.NewUInt8(1))

		result, err = b.ExecuteScript(templates.GenerateGetNetworkingAddressScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		addr := result.Value
		assert.Equal(t, addr.(cadence.String), cadence.NewString("netaddress"))

		result, err = b.ExecuteScript(templates.GenerateGetNetworkingKeyScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		key := result.Value
		assert.Equal(t, key.(cadence.String), cadence.NewString("netkey"))

		result, err = b.ExecuteScript(templates.GenerateGetStakingKeyScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		key = result.Value
		assert.Equal(t, key.(cadence.String), cadence.NewString("stakekey"))

		result, err = b.ExecuteScript(templates.GenerateGetInitialWeightScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		weight := result.Value
		assert.Equal(t, weight.(cadence.UInt64), cadence.NewUInt64(0))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("250000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

	})

	t.Run("Shouldn't be able to create Node with a duplicate id", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		// Invalid: This ID has already been used
		_ = tx.AddArgument(cadence.NewString(adminID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("netaddress"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err := cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)
	})

	t.Run("Shouldn't be able to create Nodes with duplicate fields", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		// Invalid: "netaddress" is already in use
		_ = tx.AddArgument(cadence.NewString("netaddress"))
		_ = tx.AddArgument(cadence.NewString("netkey2"))
		_ = tx.AddArgument(cadence.NewString("stakekey2"))
		tokenAmount, err := cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("netaddress2"))
		// Invalid: "netkey" is already in use
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey2"))
		tokenAmount, err = cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("netaddress2"))
		_ = tx.AddArgument(cadence.NewString("netkey2"))
		// Invalid: "stakekey" is already in use
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err = cadence.NewUFix64("250000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)
	})

	t.Run("Should be able to create more valid Node structs", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(cadence.NewString("netaddress2"))
		_ = tx.AddArgument(cadence.NewString("netkey2"))
		_ = tx.AddArgument(cadence.NewString("stakekey2"))
		tokenAmount, err := cadence.NewUFix64("480000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("480000.0"), balance.(cadence.UFix64))

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		_ = tx.AddArgument(cadence.NewString(maxID))
		_ = tx.AddArgument(cadence.NewUInt8(3))
		_ = tx.AddArgument(cadence.NewString("netaddress3"))
		_ = tx.AddArgument(cadence.NewString("netkey3"))
		_ = tx.AddArgument(cadence.NewString("stakekey3"))
		tokenAmount, err = cadence.NewUFix64("1350000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateReturnCurrentTableScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		currentIDs := result.Value
		idArray := currentIDs.(cadence.Array).Values
		assert.Equal(t, 0, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Equal(t, 2, len(idArray))
	})

	t.Run("Shouldn't be able to remove a Node that doesn't exist", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRemoveNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(nonexistantID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)
	})

	t.Run("Should be able to remove a Node from the proposed record and add it back", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRemoveNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(joshID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateReturnCurrentTableScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		currentIDs := result.Value
		idArray := currentIDs.(cadence.Array).Values
		assert.Equal(t, 0, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Equal(t, 2, len(idArray))

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(joshID))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(cadence.NewString("netaddress2"))
		_ = tx.AddArgument(cadence.NewString("netkey2"))
		_ = tx.AddArgument(cadence.NewString("stakekey2"))
		tokenAmount, err := cadence.NewUFix64("480000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs = result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Equal(t, 2, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("480000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to commit additional tokens for a node", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateStakeNewTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("1450000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should not be able request unstaking for more than is available", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeTokensScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

	t.Run("Should be able to request unstaking which moves from comitted to unlocked", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeTokensScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("1350000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("100000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to withdraw tokens from unlocked", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateWithdrawUnlockedTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		result, err := b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("50000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to commit unlocked tokens", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateStakeUnlockedTokensScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		result, err := b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("1400000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to end the staking auction, which removes insufficiently staked nodes", func(t *testing.T) {

		result, err := b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("480000.0"), balance.(cadence.UFix64))

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndStakingScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		err = tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID), cadence.NewString(maxID)}))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray := proposedIDs.(cadence.Array).Values
		assert.Equal(t, 2, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("250000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("480000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("1400000.0"), balance.(cadence.UFix64))

	})

	t.Run("Should pay rewards, but no balances are increased because nobody is staked", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GeneratePayRewardsScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("480000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

	})

	t.Run("Should Move committed tokens to staked buckets", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateMoveTokensScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("480000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("250000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("1400000.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to commit unlocked and new tokens from the node who was not included", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateStakeUnlockedTokensScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetScript(templates.GenerateStakeNewTokensScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		result, err := b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("580000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to request unstaking from a staked node", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeTokensScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		tokenAmount, err := cadence.NewUFix64("50000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("50000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("250000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("200000.0"), balance.(cadence.UFix64))
	})

	/************* Start of Delegation Tests *******************/

	t.Run("Should be able to register first account to delegate to max", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateRegisterDelegatorScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetScript(templates.GenerateRegisterDelegatorScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetScript(templates.GenerateRegisterDelegatorScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetScript(templates.GenerateRegisterDelegatorScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

	t.Run("Should be able to delegate new tokens to josh", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorStakeNewScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("580000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("680000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("100000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to request unstake delegated tokens from Josh, which moved them from committed to unlocked", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorRequestUnstakeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("580000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("640000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("60000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnlockedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("40000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRequestScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to withdraw josh delegator's unlocked tokens", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorWithdrawUnlockedScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		result, err := b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("60000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnlockedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("20000.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to delegate unlocked tokens to josh", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorStakeUnlockedScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("580000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("660000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("80000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnlockedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to end the staking auction, which marks admin to unstake", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndStakingScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		err := tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID), cadence.NewString(maxID)}))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateReturnProposedTableScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray := proposedIDs.(cadence.Array).Values
		assert.Equal(t, 2, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("250000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("580000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))
	})

	t.Run("Should pay correct rewards, no delegators are paid because none are staked yet", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GeneratePayRewardsScript(IDTableAddr.String())).
			SetGasLimit(100000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("840000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("1400000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens := result.Value
		assert.Equal(t, CadenceUFix64("1400000.0"), tokens.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("387660.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

	})

	t.Run("Should Move tokens between buckets", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateMoveTokensScript(IDTableAddr.String())).
			SetGasLimit(100000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		// Admin buckets

		result, err := b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("250000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("840000.0"), balance.(cadence.UFix64))

		// josh buckets

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("580000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		// Josh Delegator Buckets

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnlockedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("80000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRequestScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		// Max buckets

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("1400000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("387660.0"), balance.(cadence.UFix64))

		// Max Delegator Buckets

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnlockedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRequestScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

	})

	t.Run("Should create new execution node", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(bastianAddress)

		_ = tx.AddArgument(cadence.NewString(bastianID))
		_ = tx.AddArgument(cadence.NewUInt8(3))
		_ = tx.AddArgument(cadence.NewString("netaddress4"))
		_ = tx.AddArgument(cadence.NewString("netkey4"))
		_ = tx.AddArgument(cadence.NewString("stakekey4"))
		tokenAmount, err := cadence.NewUFix64("1400000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, bastianAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), bastianSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(bastianID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("1400000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to delegate new tokens to max", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorStakeNewScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetScript(templates.GenerateDelegatorStakeNewScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		result, err := b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("660000.0"), balance.(cadence.UFix64))

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeTokensScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetScript(templates.GenerateUnstakeTokensScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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
			SetScript(templates.GenerateStakeRewardedTokensScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		tokenAmount, err := cadence.NewUFix64("50000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("790000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("50000.0"), balance.(cadence.UFix64))
	})

	// Josh Delegator Requests to unstake which marks their request
	t.Run("Should be able to request unstake delegated tokens from Josh, marks as requested", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorRequestUnstakeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
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

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("620000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorCommittedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnlockedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRequestScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("40000.0"), balance.(cadence.UFix64))

	})

	// End the staking auction
	t.Run("Should be able to end the staking auction", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndStakingScript(IDTableAddr.String())).
			SetGasLimit(100000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		err := tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString(adminID), cadence.NewString(joshID), cadence.NewString(maxID), cadence.NewString(bastianID)}))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

	})

	// Move tokens between buckets. Josh delegator's should be in the unstaked bucket
	// also make sure that the total totens for the #3 node role is correct
	// Make sure that admin's unstaked were moved into their unlocked
	t.Run("Should Move tokens between buckets", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateMoveTokensScript(IDTableAddr.String())).
			SetGasLimit(100000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("300000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("580000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("40000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("40000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("620000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("1400000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("100000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("200000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(bastianID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("1400000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensStakedByTypeScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("3100000.0"), balance.(cadence.UFix64))

	})

	// Pay rewards and make sure josh and josh delegator got paid the right amounts based on the cut
	t.Run("Should pay correct rewards, rewards are split up properly between stakers and delegators", func(t *testing.T) {

		result, err := b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("790000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("387660.0"), balance.(cadence.UFix64))

		tx := flow.NewTransaction().
			SetScript(templates.GeneratePayRewardsScript(IDTableAddr.String())).
			SetGasLimit(100000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("790000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("2423545.88"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("161792.12"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("563503.2"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("12105.6"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(secondDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("24211.2"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetRewardBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(bastianID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("174720.0"), balance.(cadence.UFix64))

	})

	// Move tokens. make sure josh delegators unstaked tokens are moved into their unlocked bucket
	t.Run("Should Move tokens between buckets", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateMoveTokensScript(IDTableAddr.String())).
			SetGasLimit(100000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDelegatorStakedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("40000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnstakedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetDelegatorUnlockedScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(joshID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("40000.0"), balance.(cadence.UFix64))

	})

	// Max Delegator Withdraws rewards
	t.Run("Should be able to withdraw delegator rewards", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateDelegatorWithdrawRewardsScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxDelegatorOneAddress)

		tokenAmount, err := cadence.NewUFix64("5000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxDelegatorOneAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxDelegatorOneSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDelegatorRewardsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(maxID)), jsoncdc.MustEncode(cadence.UInt32(firstDelegatorID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("7105.6"), balance.(cadence.UFix64))

	})
}
