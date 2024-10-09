package test

import (
	"context"
	"fmt"
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	emulator "github.com/onflow/flow-emulator/emulator"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/onflow/flow-go-sdk/test"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

func TestDKG(t *testing.T) {
	b, adapter := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
		BurnerAddress:        emulatorServiceAccount,
		StorageFeesAddress:   emulatorServiceAccount,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the DKG account and deploy
	DKGAccountKey, DKGSigner := accountKeys.NewWithSigner()
	DKGCode := contracts.FlowDKG()

	DKGAddress, err := adapter.CreateAccount(context.Background(), []*flow.AccountKey{DKGAccountKey}, []sdktemplates.Contract{
		{
			Name:   "FlowDKG",
			Source: string(DKGCode),
		},
	})
	assert.NoError(t, err)

	env.DkgAddress = DKGAddress.Hex()

	// Create new user accounts
	joshAccountKey, joshSigner := accountKeys.NewWithSigner()
	joshAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{joshAccountKey}, nil)

	jordanAccountKey, jordanSigner := accountKeys.NewWithSigner()
	jordanAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{jordanAccountKey}, nil)

	t.Run("Should be able to set up the admin account", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GeneratePublishDKGAdminScript(env), DKGAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			false,
		)
	})

	t.Run("Should be able to register a voter before the dkg is enabled", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), jordanAddress)

		stringArg, _ := cadence.NewString(accessID)
		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		_ = tx.AddArgument(stringArg)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{jordanAddress},
			[]crypto.Signer{jordanSigner},
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
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGWhiteBoardMessagesScript(env), nil)
		assert.Equal(t, 0, len(result.(cadence.Array).Values))
	})

	////////////////////////// FIRST EPOCH ///////////////////////////////////

	// In the first there is one DKG participant (nodeID=adminID)
	dkgNodeIDStrings := []cadence.Value{cadence.String(adminID)}
	dkgNodeIDsCadenceArray := cadence.Array{Values: []cadence.Value{cadence.String(adminID)}}.WithType(cadence.NewVariableSizedArrayType(cadence.StringType))

	t.Run("Should start dkg where the only participant is admin", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartDKGScript(env), DKGAddress)
		err := tx.AddArgument(cadence.NewArray(dkgNodeIDStrings))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		// AdminID is registered for this epoch by the admin
		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetConsensusNodesScript(env), nil)
		assert.Equal(t, dkgNodeIDsCadenceArray, result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGFinalSubmissionsScript(env), nil)
		assert.Equal(t, 0, len(result.(cadence.Array).Values))

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)
	})

	t.Run("Should not be able to start dkg when it is already running", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartDKGScript(env), DKGAddress)

		err := tx.AddArgument(cadence.NewArray(dkgNodeIDStrings))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetConsensusNodesScript(env), nil)
		assert.Equal(t, dkgNodeIDsCadenceArray, result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGFinalSubmissionsScript(env), nil)
		assert.Equal(t, 0, len(result.(cadence.Array).Values))
	})

	t.Run("Should be able to register a dkg participant", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), DKGAddress)

		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		stringArg, _ := cadence.NewString(adminID)
		_ = tx.AddArgument(stringArg)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
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
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)
	})

	t.Run("Should not be able to register a dkg participant if the node has already been registered", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), joshAddress)
		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		_ = tx.AddArgument(cadence.String(adminID)) // same ID as registered above

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			true,
		)
	})

	t.Run("Should not be able to post an empty message", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), DKGAddress)
		_ = tx.AddArgument(cadence.String(""))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)

		// TODO this should read messages, not submissions
		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeHasFinalSubmittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assert.Equal(t, cadence.NewBool(false), result)
	})

	t.Run("Should be able to post a message", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), DKGAddress)
		_ = tx.AddArgument(cadence.String("hello world!"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			false,
		)

		// TODO read messages and verify
	})

	// TODO: remove (dupe of "Admin should not be able to stop the dkg if not enough nodes have submitted")
	t.Run("Admin should not be able to stop the dkg if not enough submissions are in", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStopDKGScript(env), DKGAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)
	})

	dkgKey1 := fmt.Sprintf("%0192d", admin)

	// TODO: update to use ResultSubmission
	t.Run("Should not be able to make a final submission with an invalid submission length", func(t *testing.T) {

		finalSubmissionKeysBadLength := make([]cadence.Value, 1)
		stringArg, _ := cadence.NewString(dkgKey1)
		finalSubmissionKeysBadLength[0] = cadence.NewOptional(stringArg)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)

		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeysBadLength))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)
	})

	finalSubmissionKeys := make([]cadence.Value, 2)

	// TODO: update to use ResultSubmission
	t.Run("Should not be able to make a final submission with an invalid key length", func(t *testing.T) {

		stringArg, _ := cadence.NewString("000020202")
		finalSubmissionKeys[0] = cadence.NewOptional(stringArg)
		finalSubmissionKeys[1] = cadence.NewOptional(stringArg)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)

		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeys))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)
	})

	submission := ResultSubmission{
		GroupPubKey: DKGPubKeyFixture(),
		PubKeys:     DKGPubKeysFixture(1),
		IDMapping:   map[string]int{adminID: 0},
	}

	t.Run("Should be able to make a final submission", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)
		err := tx.AddArgument(submission.GroupPubKeyCDC())
		require.NoError(t, err)
		err = tx.AddArgument(submission.PubKeysCDC())
		require.NoError(t, err)
		err = tx.AddArgument(submission.IDMappingCDC())
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeHasFinalSubmittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

	})

	// Re-submitting (even the same result) should revert
	t.Run("Should not be able to make a second final submission", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)
		err := tx.AddArgument(submission.GroupPubKeyCDC())
		require.NoError(t, err)
		err = tx.AddArgument(submission.PubKeysCDC())
		require.NoError(t, err)
		err = tx.AddArgument(submission.IDMappingCDC())
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)

	})

	t.Run("Admin should be able to stop the dkg", func(t *testing.T) {

		result := executeScriptAndCheck(t, b, templates.GenerateGetConsensusNodesScript(env), nil)
		assert.Equal(t, dkgNodeIDsCadenceArray, result)

		submissions := GetDKGFinalSubmissions(t, b, env)
		assert.Equal(t, []ResultSubmission{submission}, submissions)

		canonicalSubmission := GetDKGCanonicalFinalSubmission(t, b, env)
		assert.Equal(t, submission, canonicalSubmission)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStopDKGScript(env), DKGAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
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
	maxAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{maxAccountKey}, nil)

	// Create a new user account
	bastianAccountKey, bastianSigner := accountKeys.NewWithSigner()
	bastianAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{bastianAccountKey}, nil)

	epoch2dkgNodeIDStrings := []string{maxID, bastianID}
	epoch2DKGNodeIDStringsCDC := CadenceArrayFrom(epoch2dkgNodeIDStrings, StringToCDC)

	t.Run("Should start dkg with the admin", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartDKGScript(env), DKGAddress)
		err := tx.AddArgument(epoch2DKGNodeIDStringsCDC)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			false,
		)

		// DKG participant from epoch 1 is NOT registered for this epoch
		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assert.Equal(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetConsensusNodesScript(env), nil)
		assert.ElementsMatch(t, epoch2dkgNodeIDStrings, CadenceArrayTo(result, CDCToString))

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGFinalSubmissionsScript(env), nil)
		assert.Equal(t, 0, len(result.(cadence.Array).Values))

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGWhiteBoardMessagesScript(env), nil)
		assert.Equal(t, 0, len(result.(cadence.Array).Values))
	})

	t.Run("Should not be able to post a message from a node that wasn't included", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), DKGAddress)
		_ = tx.AddArgument(cadence.String("am I still alive?"))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)
	})

	t.Run("Should be able to register, post messages and read messages", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), maxAddress)
		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		stringArg, _ := cadence.NewString(maxID)
		_ = tx.AddArgument(stringArg)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{maxAddress},
			[]crypto.Signer{maxSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), bastianAddress)
		_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
		stringArg, _ = cadence.NewString(bastianID)
		_ = tx.AddArgument(stringArg)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{bastianAddress},
			[]crypto.Signer{bastianSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), maxAddress)
		firstMessage, _ := cadence.NewString("I am the new ruler!")
		_ = tx.AddArgument(firstMessage)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{maxAddress},
			[]crypto.Signer{maxSigner},
			false,
		)

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), bastianAddress)
		secondMessage, _ := cadence.NewString("No, I am!")
		_ = tx.AddArgument(secondMessage)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{bastianAddress},
			[]crypto.Signer{bastianSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGWhiteBoardMessagesScript(env), nil)

		messageValues := result.(cadence.Array).Values

		message0 := messageValues[0].(cadence.Struct)
		message1 := messageValues[1].(cadence.Struct)

		message0Fields := cadence.FieldsMappedByName(message0)
		message1Fields := cadence.FieldsMappedByName(message1)

		message0IDField := message0Fields["nodeID"]
		message0ContentField := message0Fields["content"]

		message1IDField := message1Fields["nodeID"]
		message1ContentField := message1Fields["content"]

		stringArg, _ = cadence.NewString(maxID)
		assert.Equal(t, stringArg, message0IDField)
		assert.Equal(t, firstMessage, message0ContentField)

		stringArg, _ = cadence.NewString(bastianID)
		assert.Equal(t, stringArg, message1IDField)
		assert.Equal(t, secondMessage, message1ContentField)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGLatestWhiteBoardMessagesScript(env), [][]byte{jsoncdc.MustEncode(cadence.NewInt(1))})
		// TODO script result is not checked
	})

	t.Run("Should not be able to make a final submission if not registered", func(t *testing.T) {

		// TODO: update to use ResultSubmission
		finalSubmissionKeysBadLength := make([]cadence.Value, 3)
		stringArg, _ := cadence.NewString(dkgKey1)
		finalSubmissionKeysBadLength[0] = cadence.NewOptional(stringArg)
		finalSubmissionKeysBadLength[1] = cadence.NewOptional(stringArg)
		finalSubmissionKeysBadLength[2] = cadence.NewOptional(stringArg)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)

		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeysBadLength))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)
	})

	t.Run("Should not be able to set the safe threshold while the DKG is enabled", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetSafeThresholdScript(env), DKGAddress)

		err := tx.AddArgument(CadenceUFix64("0.90"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)

	})

	t.Run("Admin Should be able to force stop the DKG", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateForceStopDKGScript(env), DKGAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			false,
		)

		// TODO assert that the DKG is stopped
	})

	// we allow the threshold percent value to be in the range [0,1.0)
	// values <0 are implicitly disallowed by the unsigned type
	t.Run("Should not be able to set the safe threshold >= than 1.0", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetSafeThresholdScript(env), DKGAddress)

		err = tx.AddArgument(CadenceUFix64("1.0"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)
	})

	t.Run("Should be able to set the safe threshold in the range [0,1)", func(t *testing.T) {
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetSafeThresholdScript(env), DKGAddress)

		err = tx.AddArgument(CadenceUFix64("0.0"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			false,
		)
		checkDKGSafeThresholdPercent(t, b, env, CadenceUFix64("0.0"))

		tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateSetSafeThresholdScript(env), DKGAddress)

		err = tx.AddArgument(CadenceUFix64("0.999"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			false,
		)
		checkDKGSafeThresholdPercent(t, b, env, CadenceUFix64("0.999"))
	})

	t.Run("should be able to set the safe threshold to nil", func(t *testing.T) {
		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetSafeThresholdScript(env), DKGAddress)

		err = tx.AddArgument(cadence.NewOptional(nil))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			false,
		)

		// assert the threshold value is set
		// NOTE: nil is considered as 0 by the checker script
		checkDKGSafeThresholdPercent(t, b, env, CadenceUFix64("0.0"))
	})

	t.Run("Should be able to set the safe threshold while the DKG is disabled", func(t *testing.T) {

		// There are two consensus nodes, so the thresholds should both be zero
		// since the native percentage is floor((n-1)/2) and the safe percentage has not been set yet
		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGThresholdsScript(env), nil).(cadence.Struct)
		thresholdsFields := cadence.FieldsMappedByName(result)
		nativeThreshold := thresholdsFields["native"]
		safeThreshold := thresholdsFields["safe"]
		safePercentage := thresholdsFields["safePercentage"]

		assert.Equal(t, cadence.NewUInt64(0), nativeThreshold)
		assert.Equal(t, cadence.NewUInt64(0), safeThreshold)
		assertEqual(t, CadenceUFix64("0.0"), safePercentage)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSetSafeThresholdScript(env), DKGAddress)

		err := tx.AddArgument(CadenceUFix64("0.90"))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			false,
		)

		// The safe percentage was set to 90%, so the safe threshold should be 1
		// since there are two nodes, meaning that now, both nodes have to have
		// submitted succesfully for the DKG to be considered complete.
		checkDKGSafeThresholdPercent(t, b, env, CadenceUFix64("0.9"))
		checkDKGSafeThreshold(t, b, env, cadence.NewUInt64(1))
	})
}

// checkDKGSafeThresholdPercent asserts that the DKG safe threshold percentage
// is set to a given value.
func checkDKGSafeThresholdPercent(
	t *testing.T,
	b emulator.Emulator,
	env templates.Environment,
	expected cadence.Value, // UFix64
) {
	result := executeScriptAndCheck(t, b, templates.GenerateGetDKGThresholdsScript(env), nil).(cadence.Struct)
	safePercentage := cadence.SearchFieldByName(result, "safePercentage")
	assertEqual(t, expected, safePercentage)
}

// checkDKGSafeThreshold asserts that the DKG safe threshold is set to a given
// value. This is the max of safetyPercent*n and floor((n-1)/2) (native threshold)
func checkDKGSafeThreshold(
	t *testing.T,
	b emulator.Emulator,
	env templates.Environment,
	expected cadence.Value, // UInt64
) {
	result := executeScriptAndCheck(t, b, templates.GenerateGetDKGThresholdsScript(env), nil).(cadence.Struct)
	safeThreshold := cadence.SearchFieldByName(result, "safe")
	assertEqual(t, expected, safeThreshold)
}

// Tests the DKG with submissions consisting of nil keys.
// With 2 participants, the threshold is floor((n-1)/2) = 0, so 1 valid submission is sufficient to end the DKG.
// In the first subtest, we submit one empty submission and validate that this does not end the DKG.
// In the second subtest, we submit one non-empty submission and validate that this does end the DKG.
func TestDKGNil(t *testing.T) {
	b, adapter := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the DKG account and deploy
	DKGAccountKey, DKGSigner := accountKeys.NewWithSigner()
	DKGCode := contracts.FlowDKG()

	DKGAddress, err := adapter.CreateAccount(context.Background(), []*flow.AccountKey{DKGAccountKey}, []sdktemplates.Contract{
		{
			Name:   "FlowDKG",
			Source: string(DKGCode),
		},
	})
	assert.NoError(t, err)

	env.DkgAddress = DKGAddress.Hex()

	jordanAccountKey, jordanSigner := accountKeys.NewWithSigner()
	jordanAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{jordanAccountKey}, nil)

	// set up the admin account
	tx := createTxWithTemplateAndAuthorizer(b, templates.GeneratePublishDKGAdminScript(env), DKGAddress)
	signAndSubmit(
		t, b, tx,
		[]flow.Address{DKGAddress},
		[]crypto.Signer{DKGSigner},
		false,
	)

	// register a node dkg participant
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), jordanAddress)
	_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
	_ = tx.AddArgument(cadence.String(accessID))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{jordanAddress},
		[]crypto.Signer{jordanSigner},
		false,
	)

	dkgNodeIDStrings := []cadence.Value{cadence.String(adminID), cadence.String(accessID)}

	// Start the DKG
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateStartDKGScript(env), DKGAddress)

	err = tx.AddArgument(cadence.NewArray(dkgNodeIDStrings))
	require.NoError(t, err)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{DKGAddress},
		[]crypto.Signer{DKGSigner},
		false,
	)

	// Register another DKG participant
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), DKGAddress)

	_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
	_ = tx.AddArgument(cadence.String(adminID))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{DKGAddress},
		[]crypto.Signer{DKGSigner},
		false,
	)

	// Although one submission exceeds the threshold (0), since it is empty it does not count toward completion.
	t.Run("Should be able to make an empty final submission, but not count as completed", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendEmptyDKGFinalSubmissionScript(env), DKGAddress)
		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeHasFinalSubmittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(false), result)
	})

	// In the previous test case, 1/2 participants submitted an empty result.
	// Now, when the second participant submits a non-empty result, the DKG should be considered complete.
	t.Run("Should count as completed even if >threshold participants sent nil keys", func(t *testing.T) {
		submission := ResultSubmission{
			GroupPubKey: DKGPubKeyFixture(),
			PubKeys:     DKGPubKeysFixture(2),
			IDMapping:   map[string]int{accessID: 0, adminID: 1},
		}

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), jordanAddress)
		err := tx.AddArgument(submission.GroupPubKeyCDC())
		require.NoError(t, err)
		err = tx.AddArgument(submission.PubKeysCDC())
		require.NoError(t, err)
		err = tx.AddArgument(submission.IDMappingCDC())
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{jordanAddress},
			[]crypto.Signer{jordanSigner},
			false,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeHasFinalSubmittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(accessID))})
		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCompletedScript(env), nil)
		assert.Equal(t, cadence.NewBool(true), result)

	})
}
