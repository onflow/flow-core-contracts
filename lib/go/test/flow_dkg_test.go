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

const (
	dkgBadKey = "000020202"
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

		tx := createTxWithTemplateAndAuthorizer(b, templates.GeneratePublishDKGParticipantScript(env), DKGAddress)

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

	dkgNodeIDStrings := make([]cadence.Value, 1)
	dkgNodeIDStrings[0], _ = cadence.NewString(adminID)

	dkgNodeIDsCadenceArray := cadence.Array{Values: []cadence.Value{cadence.String(adminID)}}.WithType(cadence.NewVariableSizedArrayType(cadence.StringType))

	t.Run("Should start dkg with the admin", func(t *testing.T) {

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
		stringArg, _ := cadence.NewString(adminID)
		_ = tx.AddArgument(stringArg)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{joshAddress},
			[]crypto.Signer{joshSigner},
			true,
		)
	})

	t.Run("Should not be able to post an empty message", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), DKGAddress)

		stringArg, _ := cadence.NewString("")
		_ = tx.AddArgument(stringArg)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)

		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeHasFinalSubmittedScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})

		assert.Equal(t, cadence.NewBool(false), result)
	})

	t.Run("Should be able to post a message", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), DKGAddress)

		stringArg, _ := cadence.NewString("hello world!")
		_ = tx.AddArgument(stringArg)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			false,
		)
	})

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

	t.Run("Should not be able to make a final submission with an invalid key length", func(t *testing.T) {

		stringArg, _ := cadence.NewString(dkgBadKey)
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

	// TODO: test empty submission
	t.Run("Should be able to make a final submission", func(t *testing.T) {

		groupKey := DKGPubKeyFixture()
		pubKeys := DKGPubKeysFixture(1)
		idMapping := MakeDKGIDMappingCDC(map[string]int{adminID: 0})

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)

		err := tx.AddArgument(groupKey)
		require.NoError(t, err)
		err = tx.AddArgument(pubKeys)
		require.NoError(t, err)
		err = tx.AddArgument(idMapping)
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

	t.Run("Should not be able to make a second final submission", func(t *testing.T) {

		groupKey := DKGPubKeyFixture()
		pubKeys := DKGPubKeysFixture(1)
		idMapping := MakeDKGIDMappingCDC(map[string]int{adminID: 0})

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)

		err := tx.AddArgument(groupKey)
		require.NoError(t, err)
		err = tx.AddArgument(pubKeys)
		require.NoError(t, err)
		err = tx.AddArgument(idMapping)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			true,
		)

	})

	finalSubmissionKeysArray := cadence.Array{Values: []cadence.Value{finalSubmissionKeys[0], finalSubmissionKeys[1]}}.WithType(cadence.NewVariableSizedArrayType(cadence.NewOptionalType(cadence.StringType)))

	finalSubmissionsArray := cadence.Array{Values: []cadence.Value{finalSubmissionKeysArray}}.WithType(cadence.NewVariableSizedArrayType(cadence.NewVariableSizedArrayType(cadence.NewOptionalType(cadence.StringType))))

	t.Run("Admin should be able to stop the dkg", func(t *testing.T) {

		result := executeScriptAndCheck(t, b, templates.GenerateGetConsensusNodesScript(env), nil)

		assert.Equal(t, dkgNodeIDsCadenceArray, result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGFinalSubmissionsScript(env), nil)
		assert.Equal(t, finalSubmissionsArray, result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGCanonicalFinalSubmissionScript(env), nil)
		resultValue := result.(cadence.Optional).Value
		assert.Equal(t, finalSubmissionKeysArray, resultValue)

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

	epoch2dkgNodeIDStrings := make([]cadence.Value, 2)

	stringArg, _ := cadence.NewString(maxID)
	epoch2dkgNodeIDStrings[0] = stringArg
	stringArg, _ = cadence.NewString(bastianID)
	epoch2dkgNodeIDStrings[1] = stringArg

	t.Run("Should start dkg with the admin", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartDKGScript(env), DKGAddress)

		err := tx.AddArgument(cadence.NewArray(epoch2dkgNodeIDStrings))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{DKGAddress},
			[]crypto.Signer{DKGSigner},
			false,
		)

		// AdminID is registered for this epoch by the admin
		result := executeScriptAndCheck(t, b, templates.GenerateGetDKGNodeIsRegisteredScript(env), [][]byte{jsoncdc.MustEncode(cadence.String(adminID))})

		assert.Equal(t, cadence.NewBool(false), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetConsensusNodesScript(env), nil)

		assert.Equal(t, cadence.NewArray(epoch2dkgNodeIDStrings).WithType(cadence.NewVariableSizedArrayType(cadence.StringType)), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGFinalSubmissionsScript(env), nil)

		assert.Equal(t, 0, len(result.(cadence.Array).Values))

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGEnabledScript(env), nil)

		assert.Equal(t, cadence.NewBool(true), result)

		result = executeScriptAndCheck(t, b, templates.GenerateGetDKGWhiteBoardMessagesScript(env), nil)

		assert.Equal(t, 0, len(result.(cadence.Array).Values))
	})

	t.Run("Should not be able to post a message from a node that wasn't included", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGWhiteboardMessageScript(env), DKGAddress)

		stringArg, _ := cadence.NewString("am I still alive?")
		_ = tx.AddArgument(stringArg)

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
	})

	t.Run("Should not be able to make a final submission if not registered", func(t *testing.T) {

		finalSubmissionKeysBadLength := make([]cadence.Value, 3)
		stringArg, _ = cadence.NewString(dkgKey1)
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

// Tests the DKG with submissions consisting of nil keys
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
	tx := createTxWithTemplateAndAuthorizer(b, templates.GeneratePublishDKGParticipantScript(env), DKGAddress)
	signAndSubmit(
		t, b, tx,
		[]flow.Address{DKGAddress},
		[]crypto.Signer{DKGSigner},
		false,
	)

	// register a node dkg participant
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCreateDKGParticipantScript(env), jordanAddress)
	_ = tx.AddArgument(cadence.NewAddress(DKGAddress))
	stringArg, _ := cadence.NewString(accessID)
	_ = tx.AddArgument(stringArg)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{jordanAddress},
		[]crypto.Signer{jordanSigner},
		false,
	)

	dkgNodeIDStrings := make([]cadence.Value, 2)

	stringArg, _ = cadence.NewString(adminID)
	dkgNodeIDStrings[0] = stringArg
	stringArg, _ = cadence.NewString(accessID)
	dkgNodeIDStrings[1] = stringArg

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
	stringArg, _ = cadence.NewString(adminID)
	_ = tx.AddArgument(stringArg)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{DKGAddress},
		[]crypto.Signer{DKGSigner},
		false,
	)

	finalSubmissionKeys := make([]cadence.Value, 3)

	t.Run("Should be able to make a final submission with nil keys, but not count as completed", func(t *testing.T) {

		finalSubmissionKeys[0] = cadence.NewOptional(nil)
		finalSubmissionKeys[1] = cadence.NewOptional(nil)
		finalSubmissionKeys[2] = cadence.NewOptional(nil)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), DKGAddress)
		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeys))
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

		assert.Equal(t, cadence.NewBool(false), result)

	})

	dkgKey1 := fmt.Sprintf("%0192d", access)

	t.Run("Should count as completed even if 50 of participants sent nil keys", func(t *testing.T) {

		// NOTE: one participant submitted a nil key vector in the previous test case

		stringArg, _ = cadence.NewString(dkgKey1)
		finalSubmissionKeys[0] = cadence.NewOptional(stringArg)
		finalSubmissionKeys[1] = cadence.NewOptional(stringArg)
		finalSubmissionKeys[2] = cadence.NewOptional(stringArg)

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateSendDKGFinalSubmissionScript(env), jordanAddress)
		err := tx.AddArgument(cadence.NewArray(finalSubmissionKeys))
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
