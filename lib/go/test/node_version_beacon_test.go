package test

import (
	"testing"

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

func TestNodeVersionBeacon(t *testing.T) {

	b := newBlockchain()

	env := templates.Environment{
		ServiceAccountAddress: b.ServiceKey().Address.Hex(),
	}

	accountKeys := test.AccountKeyGenerator()

	versionBeaconAccountKey, versionBeaconSigner := accountKeys.NewWithSigner()

	versionBeaconContractScript := contracts.NodeVersionBeacon()

	versionBeaconAddress, err := b.CreateAccount([]*flow.AccountKey{versionBeaconAccountKey}, []sdktemplates.Contract{
		{
			Name:   "NodeVersionBeacon",
			Source: string(versionBeaconContractScript),
		},
	})
	assert.NoError(t, err)
	_, err = b.CommitBlock()
	assert.NoError(t, err)

	env.NodeVersionBeaconAddress = versionBeaconAddress.String()

	t.Run("Should have initialized contract correctly", func(t *testing.T) {

		result := executeScriptAndCheck(t, b, templates.GenerateGetVersionUpdateBufferScript(env), nil)

		// TODO 200 is an example hardcoded value, it should probably by part of contract initialization
		assertEqual(t, CadenceUInt64(200), result)
	})

	t.Run("Should be able to send new version", func(t *testing.T) {

		changeTx := createTxWithTemplateAndAuthorizer(b,
			templates.GenerateChangeVersionTableScript(env),
			versionBeaconAddress)

		versionHeight := uint64(44)
		err := changeTx.AddArgument(CadenceUInt64(versionHeight))
		require.NoError(t, err)
		versionMajor := uint8(2)
		err = changeTx.AddArgument(CadenceUInt8(versionMajor))
		require.NoError(t, err)
		versionMinor := uint8(13)
		err = changeTx.AddArgument(CadenceUInt8(versionMinor))
		require.NoError(t, err)
		versionPatch := uint8(7)
		err = changeTx.AddArgument(CadenceUInt8(versionPatch))
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
			templates.GenerateCheckVersionTableScript(env),
			versionBeaconAddress)

		txCheckResults := signAndSubmit(t, b, checkTx,
			[]flow.Address{versionBeaconAddress},
			[]crypto.Signer{versionBeaconSigner},
			false,
		)

		assert.Len(t, txCheckResults.Events, 1)

		versionEvent := VersionBeaconEvent(txCheckResults.Events[0])

		versionTable := versionEvent.VersionTable()

		assert.Len(t, versionTable, 1)
		assert.Equal(t, versionHeight, versionTable[0].height)

		semver := semver.New(versionTable[0].version)

		assert.Equal(t, versionMajor, uint8(semver.Major))
		assert.Equal(t, versionMinor, uint8(semver.Minor))
		assert.Equal(t, versionPatch, uint8(semver.Patch))

	})
}

type VersionBeaconEvent flow.Event

func (v VersionBeaconEvent) Sequence() uint64 {
	return v.Value.Fields[1].(cadence.UInt64).ToGoValue().(uint64)
}

func (v VersionBeaconEvent) VersionTable() (ret []struct {
	height  uint64
	version string
}) {

	for _, cadenceVal := range v.Value.Fields[0].(cadence.Array).Values {
		height := cadenceVal.(cadence.Struct).Fields[0].(cadence.UInt64).ToGoValue().(uint64)
		version := cadenceVal.(cadence.Struct).Fields[1].(cadence.String).ToGoValue().(string)

		ret = append(ret, struct {
			height  uint64
			version string
		}{height: height, version: version})
	}

	return
}
