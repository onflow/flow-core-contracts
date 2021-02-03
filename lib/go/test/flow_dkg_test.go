package test

import (
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

const (
	dkgBadKey = "000020202"
)

func TestDKG(t *testing.T) {
	b := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the DKG account and deploy
	DKGAccountKey, DKGSigner := accountKeys.NewWithSigner()
	DKGCode := contracts.FlowDKG()

	DKGAddress, err := b.CreateAccount([]*flow.AccountKey{DKGAccountKey}, []sdktemplates.Contract{
		{
			Name:   "FlowDKG",
			Source: string(DKGCode),
		},
	})
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}

	env.DkgAddress = DKGAddress.Hex()

	// Create new user accounts
	joshAccountKey, joshSigner := accountKeys.NewWithSigner()
	joshAddress, _ := b.CreateAccount([]*flow.AccountKey{joshAccountKey}, nil)

	t.Run("Should be able to set up the admin account", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GeneratePublishDKGParticipantScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)
	})

	t.Run("Should not be able to register a voter if the node hasn't been registered as a consensus node", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateDKGParticipantScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		_ = tx.AddArgument(cadence.NewString(adminID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDKGNodeIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		registered := result.Value
		assert.Equal(t, cadence.NewBool(false), registered.(cadence.Bool))

		result, err = b.ExecuteScript(templates.GenerateGetDKGNodeIsClaimedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		claimed := result.Value
		assert.Equal(t, cadence.NewBool(false), claimed.(cadence.Bool))
	})

	t.Run("Admin should not be able to stop the dkg if it is already stopped", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStopDKGScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDKGEnabledScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		enabled := result.Value
		assert.Equal(t, cadence.NewBool(false), enabled.(cadence.Bool))

		result, err = b.ExecuteScript(templates.GenerateGetDKGCompletedScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		registered := result.Value
		assert.Equal(t, cadence.NewBool(false), registered.(cadence.Bool))

		result, err = b.ExecuteScript(templates.GenerateGetDKGWhiteBoardMessagesScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		messages := result.Value
		assert.Equal(t, cadence.NewArray(make([]cadence.Value, 0)), messages.(cadence.Array))
	})

	////////////////////////// FIRST EPOCH ///////////////////////////////////

	dkgNodeIDStrings := make([]cadence.Value, 1)

	dkgNodeIDStrings[0] = cadence.NewString(adminID)

	t.Run("Should start dkg with the admin", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStartDKGScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		err := tx.AddArgument(cadence.NewArray(dkgNodeIDStrings))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDKGEnabledScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		enabled := result.Value
		assert.Equal(t, cadence.NewBool(true), enabled.(cadence.Bool))

		// AdminID is registered for this epoch by the admin
		result, err = b.ExecuteScript(templates.GenerateGetDKGNodeIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		hasRegistered := result.Value
		assert.Equal(t, cadence.NewBool(true), hasRegistered.(cadence.Bool))

		result, err = b.ExecuteScript(templates.GenerateGetConsensusNodesScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		nodes := result.Value
		assert.Equal(t, cadence.NewArray(dkgNodeIDStrings), nodes.(cadence.Array))

		result, err = b.ExecuteScript(templates.GenerateGetDKGFinalSubmissionsScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		messages := result.Value
		assert.Equal(t, cadence.NewArray(make([]cadence.Value, 0)), messages.(cadence.Array))

		result, err = b.ExecuteScript(templates.GenerateGetDKGCompletedScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		registered := result.Value
		assert.Equal(t, cadence.NewBool(false), registered.(cadence.Bool))

	})

	t.Run("Should not be able to start dkg when it is already running", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStartDKGScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		err := tx.AddArgument(cadence.NewArray(dkgNodeIDStrings))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)

		result, err := b.ExecuteScript(templates.GenerateGetConsensusNodesScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		nodes := result.Value
		assert.Equal(t, cadence.NewArray(dkgNodeIDStrings), nodes.(cadence.Array))

		result, err = b.ExecuteScript(templates.GenerateGetDKGFinalSubmissionsScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		messages := result.Value
		assert.Equal(t, cadence.NewArray(make([]cadence.Value, 0)), messages.(cadence.Array))

	})

	t.Run("Should be able to register a dkg participant", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateDKGParticipantScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		_ = tx.AddArgument(cadence.NewString(adminID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDKGNodeIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		registered := result.Value
		assert.Equal(t, cadence.NewBool(true), registered.(cadence.Bool))

		result, err = b.ExecuteScript(templates.GenerateGetDKGNodeIsClaimedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		claimed := result.Value
		assert.Equal(t, cadence.NewBool(true), claimed.(cadence.Bool))
	})

	t.Run("Admin should not be able to stop the dkg if not enough nodes have submitted", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStopDKGScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)
	})

	t.Run("Should not be able to register a dkg participant if the node has already been registered", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateDKGParticipantScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(joshAddress)

		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		_ = tx.AddArgument(cadence.NewString(adminID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, joshAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), joshSigner},
			true,
		)
	})

	t.Run("Should not be able to post an empty message", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateSendDKGWhiteboardMessageScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		_ = tx.AddArgument(cadence.NewString(""))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDKGNodeHasFinalSubmittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		hasSubmitted := result.Value
		assert.Equal(t, cadence.NewBool(false), hasSubmitted.(cadence.Bool))
	})

	t.Run("Should be able to post a message", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateSendDKGWhiteboardMessageScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		_ = tx.AddArgument(cadence.NewString("hello world!"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)
	})

	t.Run("Admin should not be able to stop the dkg if not enough submissions are in", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStopDKGScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)
	})

	dkgKey1 := fmt.Sprintf("%0192d", admin)

	t.Run("Should not be able to make a final submission with an invalid submission length", func(t *testing.T) {

		finalSubmissionKeysBadLength := make([]cadence.Value, 1)
		finalSubmissionKeysBadLength[0] = cadence.NewString(dkgKey1)

		tx := flow.NewTransaction().
			SetScript(templates.GenerateSendDKGFinalSubmissionScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeysBadLength))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)
	})

	finalSubmissionKeys := make([]cadence.Value, 2)

	t.Run("Should not be able to make a final submission with an invalid key length", func(t *testing.T) {

		finalSubmissionKeys[0] = cadence.NewString(dkgBadKey)
		finalSubmissionKeys[1] = cadence.NewString(dkgBadKey)

		tx := flow.NewTransaction().
			SetScript(templates.GenerateSendDKGFinalSubmissionScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeys))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)
	})

	t.Run("Should be able to make a final submission", func(t *testing.T) {

		finalSubmissionKeys[0] = cadence.NewString(dkgKey1)
		finalSubmissionKeys[1] = cadence.NewString(dkgKey1)

		tx := flow.NewTransaction().
			SetScript(templates.GenerateSendDKGFinalSubmissionScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeys))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDKGNodeHasFinalSubmittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		hasSubmitted := result.Value
		assert.Equal(t, cadence.NewBool(true), hasSubmitted.(cadence.Bool))

		result, err = b.ExecuteScript(templates.GenerateGetDKGCompletedScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		registered := result.Value
		assert.Equal(t, cadence.NewBool(true), registered.(cadence.Bool))

	})

	t.Run("Should not be able to make a second final submission", func(t *testing.T) {

		finalSubmissionKeys[0] = cadence.NewString(dkgKey1)
		finalSubmissionKeys[1] = cadence.NewString(dkgKey1)

		tx := flow.NewTransaction().
			SetScript(templates.GenerateSendDKGFinalSubmissionScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeys))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)

	})

	t.Run("Admin should be able to stop the dkg", func(t *testing.T) {

		result, err := b.ExecuteScript(templates.GenerateGetConsensusNodesScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		nodes := result.Value
		assert.Equal(t, cadence.NewArray(dkgNodeIDStrings), nodes.(cadence.Array))

		finalSubmissionsArray := make([]cadence.Value, 1)
		finalSubmissionsArray[0] = cadence.NewArray(finalSubmissionKeys)

		result, err = b.ExecuteScript(templates.GenerateGetDKGFinalSubmissionsScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		messages := result.Value
		assert.Equal(t, cadence.NewArray(finalSubmissionsArray), messages.(cadence.Array))

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStopDKGScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)

		result, err = b.ExecuteScript(templates.GenerateGetDKGEnabledScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		enabled := result.Value
		assert.Equal(t, cadence.NewBool(false), enabled.(cadence.Bool))

		result, err = b.ExecuteScript(templates.GenerateGetDKGCompletedScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		registered := result.Value
		assert.Equal(t, cadence.NewBool(false), registered.(cadence.Bool))
	})

	// ///////////////////////////// Epoch 2 ////////////////////////////////////

	// Create a new user account
	maxAccountKey, maxSigner := accountKeys.NewWithSigner()
	maxAddress, _ := b.CreateAccount([]*flow.AccountKey{maxAccountKey}, nil)

	// Create a new user account
	bastianAccountKey, bastianSigner := accountKeys.NewWithSigner()
	bastianAddress, _ := b.CreateAccount([]*flow.AccountKey{bastianAccountKey}, nil)

	epoch2dkgNodeIDStrings := make([]cadence.Value, 2)

	epoch2dkgNodeIDStrings[0] = cadence.NewString(maxID)
	epoch2dkgNodeIDStrings[1] = cadence.NewString(bastianID)

	t.Run("Should start dkg with the admin", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStartDKGScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		err := tx.AddArgument(cadence.NewArray(epoch2dkgNodeIDStrings))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)

		// AdminID is registered for this epoch by the admin
		result, err := b.ExecuteScript(templates.GenerateGetDKGNodeIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		hasRegistered := result.Value
		assert.Equal(t, cadence.NewBool(false), hasRegistered.(cadence.Bool))

		result, err = b.ExecuteScript(templates.GenerateGetConsensusNodesScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		nodes := result.Value
		assert.Equal(t, cadence.NewArray(epoch2dkgNodeIDStrings), nodes.(cadence.Array))

		result, err = b.ExecuteScript(templates.GenerateGetDKGFinalSubmissionsScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		messages := result.Value
		assert.Equal(t, cadence.NewArray(make([]cadence.Value, 0)), messages.(cadence.Array))

		result, err = b.ExecuteScript(templates.GenerateGetDKGEnabledScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		enabled := result.Value
		assert.Equal(t, cadence.NewBool(true), enabled.(cadence.Bool))

		result, err = b.ExecuteScript(templates.GenerateGetDKGWhiteBoardMessagesScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		messages = result.Value
		assert.Equal(t, cadence.NewArray(make([]cadence.Value, 0)), messages.(cadence.Array))
	})

	t.Run("Should not be able to post a message from a node that wasn't included", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateSendDKGWhiteboardMessageScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		_ = tx.AddArgument(cadence.NewString("am I still alive?"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)
	})

	t.Run("Should be able to register, post messages and read messages", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateCreateDKGParticipantScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		_ = tx.AddArgument(cadence.NewString(maxID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateCreateDKGParticipantScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(bastianAddress)

		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		_ = tx.AddArgument(cadence.NewString(bastianID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, bastianAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), bastianSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateSendDKGWhiteboardMessageScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(maxAddress)

		_ = tx.AddArgument(cadence.NewString("I am the new ruler!"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateSendDKGWhiteboardMessageScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(bastianAddress)

		_ = tx.AddArgument(cadence.NewString("No, I am!"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, bastianAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), bastianSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateGetDKGWhiteBoardMessagesScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		messages := result.Value.(cadence.Array).Values

		message0 := messages[0].(cadence.Struct)
		message1 := messages[1].(cadence.Struct)

		message0IDField := message0.Fields[0]
		message0ContentField := message0.Fields[1]

		message1IDField := message1.Fields[0]
		message1ContentField := message1.Fields[1]

		assert.Equal(t, cadence.NewString(maxID), message0IDField)
		assert.Equal(t, cadence.NewString("I am the new ruler!"), message0ContentField)

		assert.Equal(t, cadence.NewString(bastianID), message1IDField)
		assert.Equal(t, cadence.NewString("No, I am!"), message1ContentField)
	})

	t.Run("Should not be able to make a final submission if not registered", func(t *testing.T) {

		finalSubmissionKeysBadLength := make([]cadence.Value, 3)
		finalSubmissionKeysBadLength[0] = cadence.NewString(dkgKey1)
		finalSubmissionKeysBadLength[1] = cadence.NewString(dkgKey1)
		finalSubmissionKeysBadLength[2] = cadence.NewString(dkgKey1)

		tx := flow.NewTransaction().
			SetScript(templates.GenerateSendDKGFinalSubmissionScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(DKGAddress)

		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeysBadLength))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)
	})

}
