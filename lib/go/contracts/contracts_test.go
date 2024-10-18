package contracts_test

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/onflow/flow-core-contracts/lib/go/templates"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
)

const (
	fakeAddr = "0x0A"
)

func TestFlowTokenContract(t *testing.T) {
	env := templates.Environment{
		FungibleTokenAddress: fakeAddr,
		ViewResolverAddress:  fakeAddr,
		BurnerAddress:        fakeAddr,
	}
	contract := contracts.FlowToken(env)
	assert.NotNil(t, contract)
}

func TestFlowFeesContract(t *testing.T) {
	env := templates.Environment{
		FungibleTokenAddress: fakeAddr,
		FlowTokenAddress:     fakeAddr,
		StorageFeesAddress:   fakeAddr,
	}
	contract := contracts.FlowFees(env)
	assert.NotNil(t, contract)
}

func TestStorageFeesContract(t *testing.T) {
	env := templates.Environment{
		FungibleTokenAddress: fakeAddr,
		FlowTokenAddress:     fakeAddr,
	}
	contract := contracts.FlowStorageFees(env)
	assert.NotNil(t, contract)
}

func TestFlowServiceAccountContract(t *testing.T) {
	env := templates.Environment{
		FungibleTokenAddress: fakeAddr,
		FlowTokenAddress:     fakeAddr,
		StorageFeesAddress:   fakeAddr,
		FlowFeesAddress:      fakeAddr,
	}
	contract := contracts.FlowServiceAccount(env)
	assert.NotNil(t, contract)
}

func TestFlowIdentityTableContract(t *testing.T) {
	env := templates.Environment{
		FungibleTokenAddress: fakeAddr,
		FlowTokenAddress:     fakeAddr,
		BurnerAddress:        fakeAddr,
		FlowFeesAddress:      fakeAddr,
	}
	contract := contracts.FlowIDTableStaking(env)
	assert.NotNil(t, contract)
}

func TestFlowQCContract(t *testing.T) {
	contract := contracts.FlowQC()
	assert.NotNil(t, contract)
}

func TestStakingCollection(t *testing.T) {
	env := templates.Environment{
		FungibleTokenAddress:     fakeAddr,
		FlowTokenAddress:         fakeAddr,
		StorageFeesAddress:       fakeAddr,
		IDTableAddress:           fakeAddr,
		LockedTokensAddress:      fakeAddr,
		QuorumCertificateAddress: fakeAddr,
		DkgAddress:               fakeAddr,
		EpochAddress:             fakeAddr,
	}
	contract := contracts.FlowStakingCollection(env)
	assert.NotNil(t, contract)
}

func TestNodeVersionBeacon(t *testing.T) {
	contract := contracts.NodeVersionBeacon()
	assert.NotNil(t, contract)
}

func TestCrypto(t *testing.T) {
	contract := contracts.Crypto()

	assert.NotNil(t, contract)
}
