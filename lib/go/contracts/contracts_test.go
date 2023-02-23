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
	contract := contracts.FlowToken(fakeAddr)
	assert.NotNil(t, contract)
}

func TestFlowFeesContract(t *testing.T) {
	contract := contracts.FlowFees(fakeAddr, fakeAddr, fakeAddr)
	assert.NotNil(t, contract)
}

func TestStorageFeesContract(t *testing.T) {
	contract := contracts.FlowStorageFees(fakeAddr, fakeAddr)
	assert.NotNil(t, contract)
}

func TestFlowServiceAccountContract(t *testing.T) {
	contract := contracts.FlowServiceAccount(fakeAddr, fakeAddr, fakeAddr, fakeAddr)
	assert.NotNil(t, contract)
}

func TestFlowIdentityTableContract(t *testing.T) {
	contract := contracts.FlowIDTableStaking(fakeAddr, fakeAddr, fakeAddr, true)
	assert.NotNil(t, contract)
}

func TestFlowQCContract(t *testing.T) {
	contract := contracts.FlowQC()
	assert.NotNil(t, contract)
}

func TestStakingCollection(t *testing.T) {
	contract := contracts.FlowStakingCollection(fakeAddr, fakeAddr, fakeAddr, fakeAddr, fakeAddr, fakeAddr, fakeAddr, fakeAddr, fakeAddr)
	assert.NotNil(t, contract)
}

func TestFlowContractAudits(t *testing.T) {
	contract := contracts.FlowContractAudits()
	assert.NotNil(t, contract)
}

func TestNodeVersionBeacon(t *testing.T) {
	contract := contracts.NodeVersionBeacon()
	assert.NotNil(t, contract)
}
