package test

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

// Test deploying the contract
func TestIDTableDeployment(t *testing.T) {
	b := newEmulator()

	// Should be able to deploy id contract as a new account
	IDTableCode := contracts.FlowIdentityTable()
	_, err := b.CreateAccount(nil, IDTableCode)
	assert.NoError(t, err)

	_, err = b.CommitBlock()
	assert.NoError(t, err)
}

func TestIDTable(t *testing.T) {
	b := newEmulator()

	accountKeys := test.AccountKeyGenerator()

	// Should be able to deploy id contract as a new account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	IDTableCode := contracts.FlowIdentityTable()
	IDTableAddr, err := b.CreateAccount([]*flow.AccountKey{IDTableAccountKey}, IDTableCode)
	assert.NoError(t, err)

	_, err = b.CommitBlock()
	assert.NoError(t, err)

	t.Run("Should be able to read empty table fields", func(t *testing.T) {

		result, err := b.ExecuteScript(templates.GenerateReturnCurrentTableScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		length := result.Value
		assert.Equal(t, length.(cadence.Int), cadence.NewInt(0))

		result, err = b.ExecuteScript(templates.GenerateReturnPreviousTableScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		length = result.Value
		assert.Equal(t, length.(cadence.Int), cadence.NewInt(0))
	})

	t.Run("Shouldn't be able to create invalid Node structs", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
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
		_ = tx.AddArgument(cadence.NewUInt64(10))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000001"))
		// Invalid Role: Greater than 5
		_ = tx.AddArgument(cadence.NewUInt8(6))
		_ = tx.AddArgument(cadence.NewString("12234"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		_ = tx.AddArgument(cadence.NewUInt64(10))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000001"))
		// Invalid Role: Less than 1
		_ = tx.AddArgument(cadence.NewUInt8(0))
		_ = tx.AddArgument(cadence.NewString("12234"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		_ = tx.AddArgument(cadence.NewUInt64(10))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000001"))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		// Invalid Networking Address: Length cannot be zero
		_ = tx.AddArgument(cadence.NewString(""))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		_ = tx.AddArgument(cadence.NewUInt64(1))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000001"))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("netaddress"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		// Invalid Initial Weight: Must be greater than zero
		_ = tx.AddArgument(cadence.NewUInt64(0))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

	})

	t.Run("Should be able to create a valid Node struct", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000001"))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("netaddress"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		_ = tx.AddArgument(cadence.NewUInt64(20))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

	})

	t.Run("Shouldn't be able to create Node with a duplicate id", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		// Invalid: This ID has already been used
		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000001"))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("netaddress"))
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		_ = tx.AddArgument(cadence.NewUInt64(20))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)
	})

	t.Run("Shouldn't be able to create Nodes with duplicate fields", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000002"))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		// Invalid: "netaddress" is already in use
		_ = tx.AddArgument(cadence.NewString("netaddress"))
		_ = tx.AddArgument(cadence.NewString("netkey2"))
		_ = tx.AddArgument(cadence.NewString("stakekey2"))
		_ = tx.AddArgument(cadence.NewUInt64(20))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000002"))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("netaddress2"))
		// Invalid: "netkey" is already in use
		_ = tx.AddArgument(cadence.NewString("netkey"))
		_ = tx.AddArgument(cadence.NewString("stakekey2"))
		_ = tx.AddArgument(cadence.NewUInt64(20))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000002"))
		_ = tx.AddArgument(cadence.NewUInt8(1))
		_ = tx.AddArgument(cadence.NewString("netaddress2"))
		_ = tx.AddArgument(cadence.NewString("netkey2"))
		// Invalid: "stakekey" is already in use
		_ = tx.AddArgument(cadence.NewString("stakekey"))
		_ = tx.AddArgument(cadence.NewUInt64(20))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)
	})

	t.Run("Should be able to create more valid Node structs", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000002"))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(cadence.NewString("netaddress2"))
		_ = tx.AddArgument(cadence.NewString("netkey2"))
		_ = tx.AddArgument(cadence.NewString("stakekey2"))
		_ = tx.AddArgument(cadence.NewUInt64(20))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000003"))
		_ = tx.AddArgument(cadence.NewUInt8(3))
		_ = tx.AddArgument(cadence.NewString("netaddress3"))
		_ = tx.AddArgument(cadence.NewString("netkey3"))
		_ = tx.AddArgument(cadence.NewString("stakekey3"))
		_ = tx.AddArgument(cadence.NewUInt64(20))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)
	})

	t.Run("Should be able to remove a Node from the proposed record and add it back", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRemoveNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000002"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateReturnCurrentTableScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		length := result.Value
		assert.Equal(t, length.(cadence.Int), cadence.NewInt(0))

		result, err = b.ExecuteScript(templates.GenerateReturnPreviousTableScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		length = result.Value
		assert.Equal(t, length.(cadence.Int), cadence.NewInt(0))

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		length = result.Value
		assert.Equal(t, length.(cadence.Int), cadence.NewInt(2))

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000002"))
		_ = tx.AddArgument(cadence.NewUInt8(2))
		_ = tx.AddArgument(cadence.NewString("netaddress2"))
		_ = tx.AddArgument(cadence.NewString("netkey2"))
		_ = tx.AddArgument(cadence.NewString("stakekey2"))
		_ = tx.AddArgument(cadence.NewUInt64(20))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		length = result.Value
		assert.Equal(t, length.(cadence.Int), cadence.NewInt(3))
	})

	t.Run("Should be able to trigger an update to the tables", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateUpdateTableScript(IDTableAddr.String())).
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

		result, err := b.ExecuteScript(templates.GenerateReturnCurrentTableScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		length := result.Value
		assert.Equal(t, length.(cadence.Int), cadence.NewInt(3))

		result, err = b.ExecuteScript(templates.GenerateReturnPreviousTableScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		length = result.Value
		assert.Equal(t, length.(cadence.Int), cadence.NewInt(0))

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		length = result.Value
		assert.Equal(t, length.(cadence.Int), cadence.NewInt(3))
	})

	t.Run("Should be able to create a new Node and read its Data", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateNodeScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000004"))
		_ = tx.AddArgument(cadence.NewUInt8(4))
		_ = tx.AddArgument(cadence.NewString("netaddress4"))
		_ = tx.AddArgument(cadence.NewString("netkey4"))
		_ = tx.AddArgument(cadence.NewString("stakekey4"))
		_ = tx.AddArgument(cadence.NewUInt64(20))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetRoleScript(IDTableAddr.String(), "Proposed"), [][]byte{jsoncdc.MustEncode(cadence.String("00000000000000000000000000000004"))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		role := result.Value
		assert.Equal(t, role.(cadence.UInt8), cadence.NewUInt8(4))

		result, err = b.ExecuteScript(templates.GenerateGetNetworkingAddressScript(IDTableAddr.String(), "Proposed"), [][]byte{jsoncdc.MustEncode(cadence.String("00000000000000000000000000000004"))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		addr := result.Value
		assert.Equal(t, addr.(cadence.String), cadence.NewString("netaddress4"))

		result, err = b.ExecuteScript(templates.GenerateGetNetworkingKeyScript(IDTableAddr.String(), "Proposed"), [][]byte{jsoncdc.MustEncode(cadence.String("00000000000000000000000000000004"))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		key := result.Value
		assert.Equal(t, key.(cadence.String), cadence.NewString("netkey4"))

		result, err = b.ExecuteScript(templates.GenerateGetStakingKeyScript(IDTableAddr.String(), "Proposed"), [][]byte{jsoncdc.MustEncode(cadence.String("00000000000000000000000000000004"))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		key = result.Value
		assert.Equal(t, key.(cadence.String), cadence.NewString("stakekey4"))

		result, err = b.ExecuteScript(templates.GenerateGetInitialWeightScript(IDTableAddr.String(), "Proposed"), [][]byte{jsoncdc.MustEncode(cadence.String("00000000000000000000000000000004"))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		weight := result.Value
		assert.Equal(t, weight.(cadence.UInt64), cadence.NewUInt64(20))

	})

	t.Run("Should be able to update the weight of a node", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateChangeWeightScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000004"))
		_ = tx.AddArgument(cadence.NewUInt64(0))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			true,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateChangeWeightScript(IDTableAddr.String())).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(IDTableAddr)

		_ = tx.AddArgument(cadence.NewString("00000000000000000000000000000004"))
		_ = tx.AddArgument(cadence.NewUInt64(50))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, IDTableAddr},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetInitialWeightScript(IDTableAddr.String(), "Proposed"), [][]byte{jsoncdc.MustEncode(cadence.String("00000000000000000000000000000004"))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		weight := result.Value
		assert.Equal(t, weight.(cadence.UInt64), cadence.NewUInt64(50))

	})

	t.Run("Should be able to trigger an update to the tables and see a previous epoch data", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateUpdateTableScript(IDTableAddr.String())).
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

		result, err := b.ExecuteScript(templates.GenerateReturnCurrentTableScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		length := result.Value
		assert.Equal(t, length.(cadence.Int), cadence.NewInt(4))

		result, err = b.ExecuteScript(templates.GenerateReturnPreviousTableScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		length = result.Value
		assert.Equal(t, length.(cadence.Int), cadence.NewInt(3))

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(IDTableAddr.String()), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		length = result.Value
		assert.Equal(t, length.(cadence.Int), cadence.NewInt(4))
	})

}
