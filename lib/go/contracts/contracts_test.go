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

// Sets all the env addresses to the fakeAddr so they will all be used
// to replace import placeholders in the tests
func SetAllAddresses(env *templates.Environment) {
	env.FungibleTokenAddress = fakeAddr
	env.EVMAddress = fakeAddr
	env.ViewResolverAddress = fakeAddr
	env.BurnerAddress = fakeAddr
	env.NonFungibleTokenAddress = fakeAddr
	env.MetadataViewsAddress = fakeAddr
	env.CryptoAddress = fakeAddr
	env.FlowFeesAddress = fakeAddr
	env.FlowTokenAddress = fakeAddr
	env.FungibleTokenMetadataViewsAddress = fakeAddr
	env.StorageFeesAddress = fakeAddr
	env.FungibleTokenSwitchboardAddress = fakeAddr
	env.FlowTokenAddress = fakeAddr
	env.IDTableAddress = fakeAddr
	env.LockedTokensAddress = fakeAddr
	env.StakingProxyAddress = fakeAddr
	env.QuorumCertificateAddress = fakeAddr
	env.DkgAddress = fakeAddr
	env.EpochAddress = fakeAddr
	env.StakingCollectionAddress = fakeAddr
	env.FlowExecutionParametersAddress = fakeAddr
	env.ServiceAccountAddress = fakeAddr
	env.NodeVersionBeaconAddress = fakeAddr
	env.RandomBeaconHistoryAddress = fakeAddr
	env.FlowCallbackSchedulerAddress = fakeAddr
}

// Tests that a specific contract path should succeed when retrieving it
// and verifies that all the import placeholders have been replaced
func GetCadenceContractShouldSucceed(t *testing.T, contract string) {
	assert.NotNil(t, contract)
	assert.NotContains(t, string(contract), "import \"")
	assert.NotContains(t, string(contract), "import 0x")
}

func TestFlowTokenContract(t *testing.T) {
	env := templates.Environment{
		FungibleTokenAddress:              fakeAddr,
		FungibleTokenMetadataViewsAddress: fakeAddr,
		MetadataViewsAddress:              fakeAddr,
		ViewResolverAddress:               fakeAddr,
		BurnerAddress:                     fakeAddr,
	}
	contract := string(contracts.FlowToken(env))
	GetCadenceContractShouldSucceed(t, contract)
	assert.Contains(t, contract, "import FungibleToken from 0x")
	assert.Contains(t, contract, "import FungibleTokenMetadataViews from 0x")
	assert.Contains(t, contract, "import MetadataViews from 0x")
}

func TestFlowFeesContract(t *testing.T) {
	env := templates.Environment{}
	SetAllAddresses(&env)
	contract := string(contracts.FlowFees(env))
	GetCadenceContractShouldSucceed(t, contract)
	assert.Contains(t, contract, "import FungibleToken from 0x")
	assert.Contains(t, contract, "import FlowToken from 0x")
	assert.Contains(t, contract, "import FlowStorageFees from 0x")
}

func TestStorageFeesContract(t *testing.T) {
	env := templates.Environment{}
	SetAllAddresses(&env)
	contract := string(contracts.FlowStorageFees(env))
	GetCadenceContractShouldSucceed(t, contract)
	assert.Contains(t, contract, "import FungibleToken from 0x")
	assert.Contains(t, contract, "import FlowToken from 0x")
}

func TestFlowServiceAccountContract(t *testing.T) {
	env := templates.Environment{}
	SetAllAddresses(&env)
	contract := string(contracts.FlowServiceAccount(env))
	GetCadenceContractShouldSucceed(t, contract)
	assert.Contains(t, contract, "import FungibleToken from 0x")
	assert.Contains(t, contract, "import FlowToken from 0x")
	assert.Contains(t, contract, "import FlowStorageFees from 0x")
	assert.Contains(t, contract, "import FlowFees from 0x")
	assert.Contains(t, contract, "import FlowExecutionParameters from 0x")
}

func TestFlowIdentityTableContract(t *testing.T) {
	env := templates.Environment{}
	SetAllAddresses(&env)
	contract := string(contracts.FlowIDTableStaking(env))
	GetCadenceContractShouldSucceed(t, contract)
	assert.Contains(t, contract, "import FungibleToken from 0x")
	assert.Contains(t, contract, "import FlowToken from 0x")
	assert.Contains(t, contract, "import Burner from 0x")
	assert.Contains(t, contract, "import FlowFees from 0x")
}

func TestFlowQCContract(t *testing.T) {
	contract := string(contracts.FlowQC())
	GetCadenceContractShouldSucceed(t, contract)
}

func TestFlowDKG(t *testing.T) {
	contract := string(contracts.FlowDKG())
	GetCadenceContractShouldSucceed(t, contract)
}

func TestFlowEpoch(t *testing.T) {
	env := templates.Environment{}
	SetAllAddresses(&env)
	contract := string(contracts.FlowEpoch(env))
	GetCadenceContractShouldSucceed(t, contract)
	assert.Contains(t, contract, "import FungibleToken from 0x")
	assert.Contains(t, contract, "import FlowToken from 0x")
	assert.Contains(t, contract, "import FlowIDTableStaking from 0x")
	assert.Contains(t, contract, "import FlowClusterQC from 0x")
	assert.Contains(t, contract, "import FlowDKG from 0x")
	assert.Contains(t, contract, "import FlowFees from 0x")
}

func TestStakingProxy(t *testing.T) {
	contract := string(contracts.FlowStakingProxy())
	GetCadenceContractShouldSucceed(t, contract)
}

func TestLockedTokens(t *testing.T) {
	env := templates.Environment{}
	SetAllAddresses(&env)
	contract := string(contracts.FlowLockedTokens(env))
	GetCadenceContractShouldSucceed(t, contract)
	assert.Contains(t, contract, "import FungibleToken from 0x")
	assert.Contains(t, contract, "import FlowToken from 0x")
	assert.Contains(t, contract, "import FlowIDTableStaking from 0x")
	assert.Contains(t, contract, "import FlowStorageFees from 0x")
	assert.Contains(t, contract, "import StakingProxy from 0x")
}

func TestStakingCollection(t *testing.T) {
	env := templates.Environment{}
	SetAllAddresses(&env)
	contract := string(contracts.FlowStakingCollection(env))
	GetCadenceContractShouldSucceed(t, contract)
	assert.Contains(t, contract, "import FungibleToken from 0x")
	assert.Contains(t, contract, "import FlowToken from 0x")
	assert.Contains(t, contract, "import FlowIDTableStaking from 0x")
	assert.Contains(t, contract, "import FlowClusterQC from 0x")
	assert.Contains(t, contract, "import FlowDKG from 0x")
	assert.Contains(t, contract, "import FlowEpoch from 0x")
	assert.Contains(t, contract, "import FlowStorageFees from 0x")
	assert.Contains(t, contract, "import Burner from 0x")
	assert.Contains(t, contract, "import LockedTokens from 0x")
}

func TestFlowCallbackScheduler(t *testing.T) {
	env := templates.Environment{}
	SetAllAddresses(&env)
	contract := string(contracts.FlowCallbackScheduler(env))
	GetCadenceContractShouldSucceed(t, contract)
	assert.Contains(t, contract, "import FlowToken from 0x")
	assert.Contains(t, contract, "import FlowFees from 0x")
}

func TestFlowCallbackUtils(t *testing.T) {
	env := templates.Environment{}
	SetAllAddresses(&env)
	contract := string(contracts.FlowCallbackUtils(env))
	GetCadenceContractShouldSucceed(t, contract)
	assert.Contains(t, contract, "import FlowToken from 0x")
	assert.Contains(t, contract, "import FlowCallbackScheduler from 0x")
}

func TestFlowCallbackHandler(t *testing.T) {
	env := templates.Environment{}
	SetAllAddresses(&env)
	contract := string(contracts.TestFlowCallbackHandler(env))
	GetCadenceContractShouldSucceed(t, contract)
	assert.Contains(t, contract, "import FlowCallbackScheduler from 0x")
}

func TestNodeVersionBeacon(t *testing.T) {
	contract := string(contracts.NodeVersionBeacon())
	GetCadenceContractShouldSucceed(t, contract)
}

func TestCrypto(t *testing.T) {
	contract := string(contracts.Crypto())
	GetCadenceContractShouldSucceed(t, contract)
}

func TestLinearCodeAddressGenerator(t *testing.T) {
	contract := string(contracts.LinearCodeAddressGenerator())
	GetCadenceContractShouldSucceed(t, contract)
}

func TestFlowExecutionParameters(t *testing.T) {
	env := templates.Environment{}
	SetAllAddresses(&env)
	contract := string(contracts.FlowExecutionParameters(env))
	GetCadenceContractShouldSucceed(t, contract)
}

func TestRandomBeaconHistory(t *testing.T) {
	contract := string(contracts.RandomBeaconHistory())
	GetCadenceContractShouldSucceed(t, contract)
}
