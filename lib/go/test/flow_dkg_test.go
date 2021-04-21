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
	assert.NoError(t, err)

	env.DkgAddress = DKGAddress.Hex()

	// Create new user accounts
	joshAccountKey, joshSigner := accountKeys.NewWithSigner()
	joshAddress, _ := b.CreateAccount([]*flow.AccountKey{joshAccountKey}, nil)

	jordanAccountKey, jordanSigner := accountKeys.NewWithSigner()
	jordanAddress, _ := b.CreateAccount([]*flow.AccountKey{jordanAccountKey}, nil)

	t.Run("Should be able to set up the admin account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GeneratePublishDKGParticipantScript(env), DKGAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)
	})

	t.Run("Should be able to register a voter before the dkg is enabled", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), jordanAddress)

		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		_ = tx.AddArgument(cadence.NewString(accessID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, jordanAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), jordanSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(accessID))})

		assert.Equal(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeIsClaimedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(accessID))})

		assert.Equal(t, cadence.NewBool(true), result)
	})

	t.Run("Admin should not be able to stop the dkg if it is already stopped", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStopDKGScript(env), DKGAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)

		assert.Equal(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)

		assert.Equal(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGWhiteBoardMessagesScript(env), nil)

		assert.Equal(t, cadence.NewArray(make([]cadence.Value, 0)), result)
	})

	////////////////////////// FIRST EPOCH ///////////////////////////////////

	dkgNodeIDStrings := make([]cadence.Value, 1)

	dkgNodeIDStrings[0] = cadence.NewString(adminID)

	t.Run("Should start dkg with the admin", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartDKGScript(env), DKGAddress)

		err := tx.AddArgument(cadence.NewArray(dkgNodeIDStrings))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)

		assert.Equal(t, cadence.NewBool(true), result)

		// AdminID is registered for this epoch by the admin
		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})

		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetConsensusNodesScript(env), nil)

		assert.Equal(t, cadence.NewArray(dkgNodeIDStrings), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGFinalSubmissionsScript(env), nil)

		assert.Equal(t, cadence.NewArray(make([]cadence.Value, 0)), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)

		assert.Equal(t, cadence.NewBool(false), result)

	})

	t.Run("Should not be able to start dkg when it is already running", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartDKGScript(env), DKGAddress)

		err := tx.AddArgument(cadence.NewArray(dkgNodeIDStrings))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetConsensusNodesScript(env), nil)

		assert.Equal(t, cadence.NewArray(dkgNodeIDStrings), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGFinalSubmissionsScript(env), nil)

		assert.Equal(t, cadence.NewArray(make([]cadence.Value, 0)), result)

	})

	t.Run("Should be able to register a dkg participant", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), DKGAddress)

		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		_ = tx.AddArgument(cadence.NewString(adminID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})

		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeIsClaimedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})

		assert.Equal(t, cadence.NewBool(true), result)
	})

	t.Run("Admin should not be able to stop the dkg if not enough nodes have submitted", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStopDKGScript(env), DKGAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)
	})

	t.Run("Should not be able to register a dkg participant if the node has already been registered", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), joshAddress)

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

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), DKGAddress)

		_ = tx.AddArgument(cadence.NewString(""))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeHasFinalSubmittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})

		assert.Equal(t, cadence.NewBool(false), result)
	})

	t.Run("Should be able to post a message", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), DKGAddress)

		_ = tx.AddArgument(cadence.NewString("hello world!"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)
	})

	t.Run("Admin should not be able to stop the dkg if not enough submissions are in", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStopDKGScript(env), DKGAddress)

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
		finalSubmissionKeysBadLength[0] = cadence.NewOptional(cadence.NewString(dkgKey1))

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)

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

		finalSubmissionKeys[0] = cadence.NewOptional(cadence.NewString(dkgBadKey))
		finalSubmissionKeys[1] = cadence.NewOptional(cadence.NewString(dkgBadKey))

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)

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

		finalSubmissionKeys[0] = cadence.NewOptional(cadence.NewString(dkgKey1))
		finalSubmissionKeys[1] = cadence.NewOptional(cadence.NewString(dkgKey1))

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)

		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeys))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeHasFinalSubmittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})

		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)

		assert.Equal(t, cadence.NewBool(true), result)

	})

	t.Run("Should not be able to make a second final submission", func(t *testing.T) {

		finalSubmissionKeys[0] = cadence.NewOptional(cadence.NewString(dkgKey1))
		finalSubmissionKeys[1] = cadence.NewOptional(cadence.NewString(dkgKey1))

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)

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

		result := executeScriptAndCheck(t, b, templates.GenerateGetConsensusNodesScript(env), nil)

		assert.Equal(t, cadence.NewArray(dkgNodeIDStrings), result)

		finalSubmissionsArray := make([]cadence.Value, 1)
		finalSubmissionsArray[0] = cadence.NewArray(finalSubmissionKeys)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGFinalSubmissionsScript(env), nil)
		assert.Equal(t, cadence.NewArray(finalSubmissionsArray), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCanonicalFinalSubmissionScript(env), nil)
		resultValue := result.(cadence.Optional).Value
		assert.Equal(t, cadence.NewArray(finalSubmissionKeys), resultValue)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStopDKGScript(env), DKGAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)

		assert.Equal(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)

		assert.Equal(t, cadence.NewBool(false), result)
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

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartDKGScript(env), DKGAddress)

		err := tx.AddArgument(cadence.NewArray(epoch2dkgNodeIDStrings))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)

		// AdminID is registered for this epoch by the admin
		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})

		assert.Equal(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetConsensusNodesScript(env), nil)

		assert.Equal(t, cadence.NewArray(epoch2dkgNodeIDStrings), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGFinalSubmissionsScript(env), nil)

		assert.Equal(t, cadence.NewArray(make([]cadence.Value, 0)), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)

		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGWhiteBoardMessagesScript(env), nil)

		assert.Equal(t, cadence.NewArray(make([]cadence.Value, 0)), result)
	})

	t.Run("Should not be able to post a message from a node that wasn't included", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), DKGAddress)

		_ = tx.AddArgument(cadence.NewString("am I still alive?"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			true,
		)
	})

	t.Run("Should be able to register, post messages and read messages", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), maxAddress)

		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		_ = tx.AddArgument(cadence.NewString(maxID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), bastianAddress)

		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		_ = tx.AddArgument(cadence.NewString(bastianID))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, bastianAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), bastianSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), maxAddress)

		_ = tx.AddArgument(cadence.NewString("I am the new ruler!"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, maxAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), maxSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), bastianAddress)

		_ = tx.AddArgument(cadence.NewString("No, I am!"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, bastianAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), bastianSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGWhiteBoardMessagesScript(env), nil)

		messageValues := result.(cadence.Array).Values

		message0 := messageValues[0].(cadence.Struct)
		message1 := messageValues[1].(cadence.Struct)

		message0IDField := message0.Fields[0]
		message0ContentField := message0.Fields[1]

		message1IDField := message1.Fields[0]
		message1ContentField := message1.Fields[1]

		assert.Equal(t, cadence.NewString(maxID), message0IDField)
		assert.Equal(t, cadence.NewString("I am the new ruler!"), message0ContentField)

		assert.Equal(t, cadence.NewString(bastianID), message1IDField)
		assert.Equal(t, cadence.NewString("No, I am!"), message1ContentField)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGLatestWhiteBoardMessagesScript(env), [][]byte{jsoncdc.MustEncode(cadence.NewInt(1))})
	})

	t.Run("Should not be able to make a final submission if not registered", func(t *testing.T) {

		finalSubmissionKeysBadLength := make([]cadence.Value, 3)
		finalSubmissionKeysBadLength[0] = cadence.NewOptional(cadence.NewString(dkgKey1))
		finalSubmissionKeysBadLength[1] = cadence.NewOptional(cadence.NewString(dkgKey1))
		finalSubmissionKeysBadLength[2] = cadence.NewOptional(cadence.NewString(dkgKey1))

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)

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

func TestDKGNil(t *testing.T) {
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
	assert.NoError(t, err)

	env.DkgAddress = DKGAddress.Hex()

	// Create new user accounts
	// joshAccountKey, joshSigner := accountKeys.NewWithSigner()
	// joshAddress, _ := b.CreateAccount([]*flow.AccountKey{joshAccountKey}, nil)

	jordanAccountKey, jordanSigner := accountKeys.NewWithSigner()
	jordanAddress, _ := b.CreateAccount([]*flow.AccountKey{jordanAccountKey}, nil)

	// set up the admin account
	tx := createTxWithTemplateAndAuthorizer(b, templates.GeneratePublishDKGParticipantScript(env), DKGAddress)
	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, DKGAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
		false,
	)

	// register a node dkg participant
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), jordanAddress)
	_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
	_ = tx.AddArgument(cadence.NewString(accessID))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, jordanAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), jordanSigner},
		false,
	)

	dkgNodeIDStrings := make([]cadence.Value, 1)

	dkgNodeIDStrings[0] = cadence.NewString(adminID)

	// Start the DKG
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateStartDKGScript(env), DKGAddress)

	err = tx.AddArgument(cadence.NewArray(dkgNodeIDStrings))
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, DKGAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
		false,
	)

	// Register another DKG participant
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), DKGAddress)

	_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
	_ = tx.AddArgument(cadence.NewString(adminID))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, DKGAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
		false,
	)

	finalSubmissionKeys := make([]cadence.Value, 2)

	t.Run("Should be able to make a final submission with nil keys, but not count as completed", func(t *testing.T) {

		finalSubmissionKeys[0] = cadence.NewOptional(nil)
		finalSubmissionKeys[1] = cadence.NewOptional(nil)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)
		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeys))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, DKGAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), DKGSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeHasFinalSubmittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})

		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)

		assert.Equal(t, cadence.NewBool(false), result)

	})
}
