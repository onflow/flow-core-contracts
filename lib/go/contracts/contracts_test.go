package contracts_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
)

const (
	fakeAddr = "0x0A"
)

func TestFlowTokenContract(t *testing.T) {
	contract := contracts.FlowToken()
	assert.NotNil(t, contract)
}

func TestFlowFeesContract(t *testing.T) {
	contract := contracts.FlowFees()
	assert.NotNil(t, contract)
}

func TestFlowServiceAccountContract(t *testing.T) {
	contract := contracts.FlowServiceAccount()
	assert.NotNil(t, contract)
}

func TestFlowIdentityTableContract(t *testing.T) {
	contract := contracts.FlowIdentityTable()
	assert.NotNil(t, contract)
}

func TestFlowStakingContract(t *testing.T) {
	contract := contracts.FlowStaking(fakeAddr, fakeAddr, fakeAddr)
	assert.NotNil(t, contract)
}
