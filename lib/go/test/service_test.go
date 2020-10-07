package test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

func TestContracts(t *testing.T) {
	b := newEmulator()

	// deploy the ServiceAccount contract
	serviceAccountCode := contracts.FlowServiceAccount(emulatorFTAddress, emulatorFlowTokenAddress, "0xe5a8b7f23e8b548f")
	_, err := b.CreateAccount(nil, serviceAccountCode)
	assert.NoError(t, err)
	_, err = b.CommitBlock()
	assert.NoError(t, err)

	// read fields on the ServiceAccount contract
	_ = executeScriptAndCheck(t, b, templates.GenerateInspectFieldScript("transactionFee"))
	_ = executeScriptAndCheck(t, b, templates.GenerateInspectFieldScript("accountCreationFee"))
}
