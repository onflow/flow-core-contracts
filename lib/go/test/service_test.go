package test

import (
	"github.com/onflow/flow-go/model/flow"
	"testing"

	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/stretchr/testify/assert"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

func TestContracts(t *testing.T) {
	b := newEmulator()
	serviceAddress := flow.Emulator.Chain().ServiceAddress()

	// deploy the ServiceAccount contract
	serviceAccountCode := contracts.FlowServiceAccount(
		emulatorFTAddress,
		emulatorFlowTokenAddress,
		"0xe5a8b7f23e8b548f",
		serviceAddress.HexWithPrefix(),
	)
	_, err := b.CreateAccount(nil, []sdktemplates.Contract{
		{
			Name: "FlowServiceAccount",
			Source: string(serviceAccountCode),
		},
	})
	assert.NoError(t, err)
	_, err = b.CommitBlock()
	assert.NoError(t, err)

	// read fields on the ServiceAccount contract
	_ = executeScriptAndCheck(t, b, templates.GenerateInspectFieldScript("transactionFee"))
	_ = executeScriptAndCheck(t, b, templates.GenerateInspectFieldScript("accountCreationFee"))
}
