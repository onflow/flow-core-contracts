package test

import (
	"testing"

	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/stretchr/testify/assert"
)

func TestContracts(t *testing.T) {
	b := newBlockchain()

	// deploy the ServiceAccount contract
	serviceAccountCode := contracts.FlowServiceAccount(
		emulatorFTAddress,
		emulatorFlowTokenAddress,
		"0xe5a8b7f23e8b548f",
	)
	_, err := b.CreateAccount(nil, []sdktemplates.Contract{
		{
			Name:   "FlowServiceAccount",
			Source: string(serviceAccountCode),
		},
	})
	assert.NoError(t, err)
	_, err = b.CommitBlock()
	assert.NoError(t, err)

	// read fields on the ServiceAccount contract
	_ = executeScriptAndCheck(t, b, templates.GenerateInspectFieldScript("transactionFee", serviceAccountAddr))
	_ = executeScriptAndCheck(t, b, templates.GenerateInspectFieldScript("accountCreationFee", serviceAccountAddr))
}
