package test

import (
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-emulator"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

func TestEpochDeployment(t *testing.T) {

	t.Parallel()

	b := newBlockchain(emulator.WithTransactionMaxGasLimit(10000000))

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	IDTableCode := contracts.FlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress)

	publicKeys := []cadence.Value{
		bytesToCadenceArray(IDTableAccountKey.Encode()),
	}

	cadencePublicKeys := cadence.NewArray(publicKeys)
	cadenceCode := bytesToCadenceArray(IDTableCode)

	// Deploy the IDTableStaking contract
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateTransferMinterAndDeployScript(env), b.ServiceKey().Address).
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

	QCCode := contracts.FlowQC()
	QCByteCode := bytesToCadenceArray(QCCode)

	DKGCode := contracts.FlowDKG()
	DKGByteCode := bytesToCadenceArray(DKGCode)

	// Deploy the QC and DKG contracts
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateDeployQCDKGScript(env), idTableAddress).
		AddRawArgument(jsoncdc.MustEncode(cadence.NewString("FlowEpochClusterQC"))).
		AddRawArgument(jsoncdc.MustEncode(QCByteCode)).
		AddRawArgument(jsoncdc.MustEncode(cadence.NewString("FlowDKG"))).
		AddRawArgument(jsoncdc.MustEncode(DKGByteCode))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, idTableAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
		false,
	)

	EpochCode := contracts.FlowEpoch(emulatorFTAddress, emulatorFlowTokenAddress, idTableAddress.String(), idTableAddress.String(), idTableAddress.String())
	EpochByteCode := bytesToCadenceArray(EpochCode)

	// Deploy the Epoch contract
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateDeployEpochScript(env), idTableAddress).
		AddRawArgument(jsoncdc.MustEncode(cadence.NewString("FlowEpoch"))).
		AddRawArgument(jsoncdc.MustEncode(EpochByteCode))

	_ = tx.AddArgument(cadence.NewUInt64(70))
	_ = tx.AddArgument(cadence.NewUInt64(50))
	_ = tx.AddArgument(cadence.NewUInt64(2))
	_ = tx.AddArgument(cadence.NewUInt16(4))
	_ = tx.AddArgument(cadence.NewString("lolsorandom"))
	_ = tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString("cluster")}))
	_ = tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString("key1"), cadence.NewString("key2")}))
	_ = tx.AddArgument(cadence.NewArray([]cadence.Value{cadence.NewString("vote1"), cadence.NewString("vote2")}))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, idTableAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
		false,
	)

}
