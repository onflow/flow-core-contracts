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
	firstID  = "0000000000000000000000000000000000000000000000000000000000000001"
	secondID = "0000000000000000000000000000000000000000000000000000000000000002"
	thirdID  = "0000000000000000000000000000000000000000000000000000000000000003"
	fourthID = "0000000000000000000000000000000000000000000000000000000000000004"

	nonexistantID = "0000000000000000000000000000000000000000000000000000000000383838383"

	FTAddress        = "ee82856bf20e2aa6"
	FlowTokenAddress = "0ae53cb6e3f42a79"
)

func TestIDTable(t *testing.T) {
	b := newEmulator()

	accountKeys := test.AccountKeyGenerator()

	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	IDTableCode := contracts.FlowIDTableStaking(FTAddress, FlowTokenAddress)

	publicKeys := make([]cadence.Value, 1)

	publicKeys[0] = bytesToCadenceArray(IDTableAccountKey.Encode())

	cadencePublicKeys := cadence.NewArray(publicKeys)
	cadenceCode := bytesToCadenceArray(IDTableCode)

	tx := flow.NewTransaction().
		SetScript(templates.GenerateTransferMinterAndDeployScript(FTAddress, FlowTokenAddress)).
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

		result, err := b.ExecuteScript(templates.GenerateReturnCurrentTableScript(FTAddress, FlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		currentIDs := result.Value
		idArray := currentIDs.(cadence.Array).Values
		assert.Equal(t, 0, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(FTAddress, FlowTokenAddress, IDTableAddr.String()), nil)
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
		assert.Equal(t, CadenceUFix64("125000.0"), requirement.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement = result.Value
		assert.Equal(t, CadenceUFix64("250000.0"), requirement.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement = result.Value
		assert.Equal(t, CadenceUFix64("625000.0"), requirement.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement = result.Value
		assert.Equal(t, CadenceUFix64("67500.0"), requirement.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakeRequirementsScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		requirement = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), requirement.(cadence.UFix64))

		/// Check that the total tokens staked for each node role are initialized correctly

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(1))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), tokens.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(2))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), tokens.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(3))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), tokens.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(4))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		tokens = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), tokens.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalTokensScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.UInt8(5))})
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
		assert.Equal(t, CadenceUFix64("250000000.0"), payout.(cadence.UFix64))

	})

	// Create new user accounts
	joshAccountKey, joshSigner := accountKeys.NewWithSigner()
	joshAddress, _ := b.CreateAccount([]*flow.AccountKey{joshAccountKey}, nil)

	// Create a new user account
	maxAccountKey, maxSigner := accountKeys.NewWithSigner()
	maxAddress, _ := b.CreateAccount([]*flow.AccountKey{maxAccountKey}, nil)

	t.Run("Should be able to mint tokens for new accounts", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(FTAddress), flow.HexToAddress(FlowTokenAddress), "FlowToken")).
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
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(FTAddress), flow.HexToAddress(FlowTokenAddress), "FlowToken")).
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
			SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(FTAddress), flow.HexToAddress(FlowTokenAddress), "FlowToken")).
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

		result, err := b.ExecuteScript(ft_templates.GenerateInspectVaultScript(flow.HexToAddress(FTAddress), flow.HexToAddress(FlowTokenAddress), "FlowToken"), [][]byte{jsoncdc.MustEncode(cadence.Address(joshAddress))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("1000000000.0"), balance.(cadence.UFix64))

	})

	t.Run("Shouldn't be able to create invalid Node structs", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
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
		tokenAmount, err := cadence.NewUFix64("125000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)
		cut, err := cadence.NewUFix64("1.0")
		require.NoError(t, err)
		_ = tx.AddArgument(cut)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(firstID))
		// Invalid Role: Greater than 5
		_ = tx.AddArgument(cadence.NewUInt8(6))
		_ = tx.AddArgument(cadence.NewString("12234"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err = cadence.NewUFix64("125000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)
		cut, err = cadence.NewUFix64("1.0")
		require.NoError(t, err)
		_ = tx.AddArgument(cut)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(firstID))
		// Invalid Role: Less than 1
		_ = tx.AddArgument(cadence.NewUInt8(0))
		_ = tx.AddArgument(cadence.NewString("12234"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err = cadence.NewUFix64("125000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)
		cut, err = cadence.NewUFix64("1.0")
		require.NoError(t, err)
		_ = tx.AddArgument(cut)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(firstID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		// Invalid Networking Address: Length cannot be zero
		_ = tx.AddArgument(cadence.NewString(""))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err = cadence.NewUFix64("125000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)
		cut, err = cadence.NewUFix64("1.0")
		require.NoError(t, err)
		_ = tx.AddArgument(cut)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

	})

	t.Run("Should be able to create a valid Node struct", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		err := tx.AddArgument(cadence.NewString(firstID))
		require.NoError(t, err)
		err = tx.AddArgument(cadence.NewUInt8(1))
		require.NoError(t, err)
		err = tx.AddArgument(cadence.NewString("netaddress"))
		require.NoError(t, err)
		err = tx.AddArgument(cadence.NewString("netkey"))
		require.NoError(t, err)
		err = tx.AddArgument(cadence.NewString("stakekey"))
		require.NoError(t, err)
		tokenAmount, err := cadence.NewUFix64("125000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)
		cut, err := cadence.NewUFix64("1.0")
		require.NoError(t, err)
		_ = tx.AddArgument(cut)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateReturnTableScript(FTAddress, FlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray := proposedIDs.(cadence.Array).Values
		assert.Equal(t, 1, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(FTAddress, FlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs = result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Equal(t, 1, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateGetRoleScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		role := result.Value
		assert.Equal(t, role.(cadence.UInt8), cadence.NewUInt8(1))

		result, err = b.ExecuteScript(templates.GenerateGetNetworkingAddressScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		addr := result.Value
		assert.Equal(t, addr.(cadence.String), cadence.NewString("netaddress"))

		result, err = b.ExecuteScript(templates.GenerateGetNetworkingKeyScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		key := result.Value
		assert.Equal(t, key.(cadence.String), cadence.NewString("netkey"))

		result, err = b.ExecuteScript(templates.GenerateGetStakingKeyScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		key = result.Value
		assert.Equal(t, key.(cadence.String), cadence.NewString("stakekey"))

		result, err = b.ExecuteScript(templates.GenerateGetInitialWeightScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		weight := result.Value
		assert.Equal(t, weight.(cadence.UInt64), cadence.NewUInt64(0))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("125000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnstakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

	})

	t.Run("Shouldn't be able to create Node with a duplicate id", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		// Invalid: This ID has already been used
		_ = tx.AddArgument(cadence.NewString(firstID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("netaddress"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err := cadence.NewUFix64("125000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)
		cut, err := cadence.NewUFix64("1.0")
		require.NoError(t, err)
		_ = tx.AddArgument(cut)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)
	})

	t.Run("Shouldn't be able to create Nodes with duplicate fields", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(secondID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		// Invalid: "netaddress" is already in use
		_ = tx.AddArgument(cadence.NewString("netaddress"))
		_ = tx.AddArgument(cadence.NewString("netkey2"))
		_ = tx.AddArgument(cadence.NewString("stakekey2"))
		tokenAmount, err := cadence.NewUFix64("125000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)
		cut, err := cadence.NewUFix64("1.0")
		require.NoError(t, err)
		_ = tx.AddArgument(cut)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(secondID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("netaddress2"))
		// Invalid: "netkey" is already in use
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey2"))
		tokenAmount, err = cadence.NewUFix64("125000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)
		cut, err = cadence.NewUFix64("1.0")
		require.NoError(t, err)
		_ = tx.AddArgument(cut)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(secondID))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("netaddress2"))
		_ = tx.AddArgument(cadence.NewString("netkey2"))
		// Invalid: "stakekey" is already in use
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		tokenAmount, err = cadence.NewUFix64("125000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)
		cut, err = cadence.NewUFix64("1.0")
		require.NoError(t, err)
		_ = tx.AddArgument(cut)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)
	})

	t.Run("Should be able to create more valid Node structs", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		_ = tx.AddArgument(cadence.NewString(secondID))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(cadence.NewString("netaddress2"))
		_ = tx.AddArgument(cadence.NewString("netkey2"))
		_ = tx.AddArgument(cadence.NewString("stakekey2"))
		tokenAmount, err := cadence.NewUFix64("240000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)
		cut, err := cadence.NewUFix64("1.0")
		require.NoError(t, err)
		_ = tx.AddArgument(cut)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(secondID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("240000.0"), balance.(cadence.UFix64))

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		_ = tx.AddArgument(cadence.NewString(thirdID))
		_ = tx.AddArgument(cadence.NewUInt8(3))
		_ = tx.AddArgument(cadence.NewString("netaddress3"))
		_ = tx.AddArgument(cadence.NewString("netkey3"))
		_ = tx.AddArgument(cadence.NewString("stakekey3"))
		tokenAmount, err = cadence.NewUFix64("650000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)
		cut, err = cadence.NewUFix64("1.0")
		require.NoError(t, err)
		_ = tx.AddArgument(cut)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateReturnCurrentTableScript(FTAddress, FlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		currentIDs := result.Value
		idArray := currentIDs.(cadence.Array).Values
		assert.Equal(t, 0, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(FTAddress, FlowTokenAddress, IDTableAddr.String()), nil)
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

		_ = tx.AddArgument(cadence.NewString(secondID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateReturnCurrentTableScript(FTAddress, FlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		currentIDs := result.Value
		idArray := currentIDs.(cadence.Array).Values
		assert.Equal(t, 0, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(FTAddress, FlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Equal(t, 2, len(idArray))

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString(secondID))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(cadence.NewString("netaddress2"))
		_ = tx.AddArgument(cadence.NewString("netkey2"))
		_ = tx.AddArgument(cadence.NewString("stakekey2"))
		tokenAmount, err := cadence.NewUFix64("240000.0")
		require.NoError(t, err)
		_ = tx.AddArgument(tokenAmount)
		cut, err := cadence.NewUFix64("1.0")
		require.NoError(t, err)
		_ = tx.AddArgument(cut)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(FTAddress, FlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs = result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Equal(t, 2, len(idArray))
	})

	t.Run("Should be able to commit additional tokens for a node", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateStakeNewTokensScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
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

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(thirdID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("700000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to request unstaking which moves from comitted to unlocked", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeTokensScript(IDTableAddr.String())).
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

		result, err := b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(thirdID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("650000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(thirdID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("50000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to withdraw tokens from unlocked", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateWithdrawTokensScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		tokenAmount, err := cadence.NewUFix64("25000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(thirdID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("25000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to commit unlocked tokens", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateStakeUnlockedTokensScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		tokenAmount, err := cadence.NewUFix64("25000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(thirdID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(thirdID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("675000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to end the staking auction, which removes insufficiently staked nodes", func(t *testing.T) {

		result, err := b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(secondID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("240000.0"), balance.(cadence.UFix64))

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndStakingScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		err = tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString(firstID), cadence.NewString(secondID), cadence.NewString(thirdID)}))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(FTAddress, FlowTokenAddress, IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray := proposedIDs.(cadence.Array).Values
		assert.Equal(t, 2, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(secondID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("240000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(secondID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

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

		result, err := b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(secondID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("240000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(thirdID))})
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

		result, err := b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(secondID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("240000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(thirdID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(secondID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(thirdID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("125000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(secondID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(thirdID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("675000.0"), balance.(cadence.UFix64))

	})

	t.Run("Should be able to commit unlocked and new tokens from the node who was not included", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateStakeUnlockedTokensScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err := cadence.NewUFix64("240000.0")
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
			SetScript(templates.GenerateStakeNewTokensScript(FTAddress, FlowTokenAddress, IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		tokenAmount, err = cadence.NewUFix64("50000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnlockedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(secondID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("0.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetCommittedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(secondID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("290000.0"), balance.(cadence.UFix64))
	})

	t.Run("Should be able to request unstaking from a staked node", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeTokensScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		tokenAmount, err := cadence.NewUFix64("25000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetUnstakingRequestScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance := result.Value
		assert.Equal(t, CadenceUFix64("25000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetStakedBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("125000.0"), balance.(cadence.UFix64))

		result, err = b.ExecuteScript(templates.GenerateGetTotalCommitmentBalanceScript(IDTableAddr.String()), [][]byte{jsoncdc.MustEncode(cadence.String(firstID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		balance = result.Value
		assert.Equal(t, CadenceUFix64("100000.0"), balance.(cadence.UFix64))
	})

}
