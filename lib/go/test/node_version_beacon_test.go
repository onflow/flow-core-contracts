package test

import (
	"context"
	"fmt"
	"testing"

	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-emulator/convert"
	"github.com/onflow/flow-emulator/emulator"
	flowgo "github.com/onflow/flow-go/model/flow"

	"github.com/coreos/go-semver/semver"
	"github.com/onflow/cadence"
	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/onflow/flow-go-sdk/test"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func deployContract(b emulator.Emulator, address flow.Address, signer crypto.Signer, contract sdktemplates.Contract, args []cadence.Value) error {

	addAccountContractTemplate := `
	transaction(name: String, code: String %s) {
		prepare(signer: auth(AddContract) &Account) {
			signer.contracts.add(name: name, code: code.decodeHex() %s)
		}
	}`

	cadenceName := cadence.String(contract.Name)
	cadenceCode := cadence.String(contract.SourceHex())

	tx := flow.NewTransaction().
		AddRawArgument(jsoncdc.MustEncode(cadenceName)).
		AddRawArgument(jsoncdc.MustEncode(cadenceCode)).
		AddAuthorizer(address).
		SetPayer(address).
		SetProposalKey(address, 0, 0)

	for _, arg := range args {
		arg.Type().ID()
		tx.AddRawArgument(jsoncdc.MustEncode(arg))
	}
	txArgs, addArgs := "", ""
	for i, arg := range args {
		txArgs += fmt.Sprintf(",arg%d:%s", i, arg.Type().ID())
		addArgs += fmt.Sprintf(",arg%d", i)
	}
	script := fmt.Sprintf(addAccountContractTemplate, txArgs, addArgs)
	tx.SetScript([]byte(script))

	tx.SetGasLimit(flowgo.DefaultMaxTransactionGasLimit)

	err := tx.SignEnvelope(address, 0, signer)
	if err != nil {
		return err
	}

	flowTx := convert.SDKTransactionToFlow(*tx)

	err = b.AddTransaction(*flowTx)
	if err != nil {
		return err
	}

	_, _, err = b.ExecuteAndCommitBlock()
	if err != nil {
		return err
	}

	return nil
}

func TestNodeVersionBeacon(t *testing.T) {

	b, adapter := newBlockchain()

	env := templates.Environment{
		ServiceAccountAddress: b.ServiceKey().Address.Hex(),
	}

	accountKeys := test.AccountKeyGenerator()

	versionBeaconAccountKey, versionBeaconSigner := accountKeys.NewWithSigner()

	versionBeaconContractScript := contracts.NodeVersionBeacon()

	versionBeaconAddress, err := adapter.CreateAccount(context.Background(), []*flow.AccountKey{versionBeaconAccountKey}, nil)
	assert.NoError(t, err)
	_, err = b.CommitBlock()
	assert.NoError(t, err)

	env.NodeVersionBeaconAddress = versionBeaconAddress.String()

	versionBeaconContract := sdktemplates.Contract{
		Name:   "NodeVersionBeacon",
		Source: string(versionBeaconContractScript),
	}

	freezePeriod := uint64(1234)

	err = deployContract(b, versionBeaconAddress, versionBeaconSigner, versionBeaconContract, []cadence.Value{cadence.UInt64(freezePeriod)})
	require.NoError(t, err)

	t.Run("Should have initialized contract correctly", func(t *testing.T) {

		result := executeScriptAndCheck(t, b, templates.GenerateGetVersionBoundaryFreezePeriodScript(env), nil)

		assertEqual(t, CadenceUInt64(freezePeriod), result)
	})

	t.Run("Should be able to send new version", func(t *testing.T) {

		changeTx := createTxWithTemplateAndAuthorizer(b,
			templates.GenerateSetVersionBoundaryScript(env),
			versionBeaconAddress)

		versionMajor := uint8(2)
		err = changeTx.AddArgument(CadenceUInt8(versionMajor))
		require.NoError(t, err)
		versionMinor := uint8(13)
		err = changeTx.AddArgument(CadenceUInt8(versionMinor))
		require.NoError(t, err)
		versionPatch := uint8(7)
		err = changeTx.AddArgument(CadenceUInt8(versionPatch))
		require.NoError(t, err)
		preRelease := ""
		err = changeTx.AddArgument(CadenceString(preRelease))
		require.NoError(t, err)
		versionHeight := freezePeriod + 44
		err := changeTx.AddArgument(CadenceUInt64(versionHeight))
		require.NoError(t, err)

		txChangeResults := signAndSubmit(
			t, b, changeTx,
			[]flow.Address{versionBeaconAddress},
			[]crypto.Signer{versionBeaconSigner},
			false,
		)
		// no events just yet
		assert.Len(t, txChangeResults.Events, 0)

		checkTx := createTxWithTemplateAndAuthorizer(b,
			templates.GenerateHeartbeatScript(env),
			versionBeaconAddress)

		txCheckResults := signAndSubmit(t, b, checkTx,
			[]flow.Address{versionBeaconAddress},
			[]crypto.Signer{versionBeaconSigner},
			false,
		)

		require.Empty(t, txCheckResults.Error)

		require.Len(t, txCheckResults.Events, 1)

		versionEvent := VersionBeaconEvent(txCheckResults.Events[0])

		versionTable := versionEvent.VersionTable()

		require.Len(t, versionTable, 2)
		require.Equal(t, uint64(0), versionTable[0].height)

		version := semver.New(versionTable[0].version)

		require.Equal(t, uint8(0), uint8(version.Major))
		require.Equal(t, uint8(0), uint8(version.Minor))
		require.Equal(t, uint8(0), uint8(version.Patch))

		require.Equal(t, versionHeight, versionTable[1].height)

		version = semver.New(versionTable[1].version)

		require.Equal(t, versionMajor, uint8(version.Major))
		require.Equal(t, versionMinor, uint8(version.Minor))
		require.Equal(t, versionPatch, uint8(version.Patch))
	})

	t.Run("Should be able to set new protocol state version", func(t *testing.T) {

		changeTx := createTxWithTemplateAndAuthorizer(b,
			templates.GenerateSetProtocolStateVersionScript(env),
			versionBeaconAddress)

		newProtocolVersion := uint64(2)
		err = changeTx.AddArgument(CadenceUInt64(newProtocolVersion))
		require.NoError(t, err)
		activeView := uint64(1000)
		err = changeTx.AddArgument(CadenceUInt64(activeView))
		require.NoError(t, err)

		txChangeResults := signAndSubmit(
			t, b, changeTx,
			[]flow.Address{versionBeaconAddress},
			[]crypto.Signer{versionBeaconSigner},
			false,
		)
		// The service event is immediately emitted within the governance transaction
		assert.Len(t, txChangeResults.Events, 1)
		assert.Empty(t, txChangeResults.Error)
		event := ProtocolStateVersionUpgradeEvent(txChangeResults.Events[0])
		assert.Equal(t, newProtocolVersion, event.NewProtocolVersion())
		assert.Equal(t, activeView, event.ActiveView())
	})
}

type VersionBeaconEvent flow.Event

func (v VersionBeaconEvent) Sequence() uint64 {
	return uint64(cadence.SearchFieldByName(v.Value, "sequence").(cadence.UInt64))
}

func (v VersionBeaconEvent) VersionTable() (ret []struct {
	height  uint64
	version string
}) {

	array := cadence.SearchFieldByName(v.Value, "versionBoundaries").(cadence.Array).Values

	for _, cadenceVal := range array {
		fields := cadence.FieldsMappedByName(cadenceVal.(cadence.Struct))
		height := uint64(fields["blockHeight"].(cadence.UInt64))
		versionFields := cadence.FieldsMappedByName(fields["version"].(cadence.Struct))

		version := fmt.Sprintf("%s.%s.%s", versionFields["major"].String(), versionFields["minor"].String(), versionFields["patch"].String())

		ret = append(ret, struct {
			height  uint64
			version string
		}{height: height, version: version})
	}

	return
}

type ProtocolStateVersionUpgradeEvent flow.Event

func (event ProtocolStateVersionUpgradeEvent) NewProtocolVersion() uint64 {
	newProtocolVersion := cadence.SearchFieldByName(event.Value, "newProtocolVersion").(cadence.UInt64)
	return uint64(newProtocolVersion)
}

func (event ProtocolStateVersionUpgradeEvent) ActiveView() uint64 {
	activeView := cadence.SearchFieldByName(event.Value, "activeView").(cadence.UInt64)
	return uint64(activeView)
}
