package contracts

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -ignore=.*_test\.cdc -ignore=.*.json -prefix ../../../contracts -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../contracts/...

import (
	"fmt"
	"strings"

	_ "github.com/kevinburke/go-bindata"
	ftcontracts "github.com/onflow/flow-ft/lib/go/contracts"
	nftcontracts "github.com/onflow/flow-nft/lib/go/contracts"

	"github.com/onflow/flow-core-contracts/lib/go/templates"

	"github.com/onflow/flow-core-contracts/lib/go/contracts/internal/assets"
)

/// This package contains utility functions to get contract code for the contracts in this repo
/// To use this package, import the `flow-core-contracts/lib/go/contracts` package,
/// then use the contracts package to call one of these functions.
/// They will return the byte array version of the contract.
///
/// Example
///
/// flowTokenCode := contracts.FlowToken(env)
///

const (
	flowFeesFilename                = "FlowFees.cdc"
	storageFeesFilename             = "FlowStorageFees.cdc"
	executionParametersFilename     = "FlowExecutionParameters.cdc"
	flowServiceAccountFilename      = "FlowServiceAccount.cdc"
	flowTokenFilename               = "FlowToken.cdc"
	flowIdentityTableFilename       = "FlowIDTableStaking.cdc"
	flowQCFilename                  = "epochs/FlowClusterQC.cdc"
	flowDKGFilename                 = "epochs/FlowDKG.cdc"
	flowEpochFilename               = "epochs/FlowEpoch.cdc"
	flowLockedTokensFilename        = "LockedTokens.cdc"
	flowStakingProxyFilename        = "StakingProxy.cdc"
	flowStakingCollectionFilename   = "FlowStakingCollection.cdc"
	flowContractAuditsFilename      = "FlowContractAudits.cdc"
	flowNodeVersionBeaconFilename   = "NodeVersionBeacon.cdc"
	flowRandomBeaconHistoryFilename = "RandomBeaconHistory.cdc"
	cryptoFilename                  = "Crypto.cdc"

	// Test contracts
	// only used for testing
	TESTFlowIdentityTableFilename = "testContracts/TestFlowIDTableStaking.cdc"

	// Each contract has placeholder addresses that need to be replaced
	// depending on which network they are being used with
	placeholderFungibleTokenAddress     = "\"FungibleToken\""
	placeholderFungibleTokenMVAddress   = "\"FungibleTokenMetadataViews\""
	placeholderMetadataViewsAddress     = "\"MetadataViews\""
	placeholderFlowTokenAddress         = "\"FlowToken\""
	placeholderIDTableAddress           = "\"FlowIDTableStaking\""
	placeholderBurnerAddress            = "\"Burner\""
	placeholderStakingProxyAddress      = "\"StakingProxy\""
	placeholderQCAddr                   = "\"FlowClusterQC\""
	placeholderDKGAddr                  = "\"FlowDKG\""
	placeholderEpochAddr                = "\"FlowEpoch\""
	placeholderFlowFeesAddress          = "\"FlowFees\""
	placeholderStorageFeesAddress       = "\"FlowStorageFees\""
	placeholderLockedTokensAddress      = "\"LockedTokens\""
	placeholderStakingCollectionAddress = "\"FlowStakingCollection\""
	placeholderNodeVersionBeaconAddress = "\"NodeVersionBeacon\""
)

// Adds a `0x` prefix to the provided address string
func withHexPrefix(address string) string {
	if address == "" {
		return ""
	}

	if address[0:2] == "0x" {
		return address
	}

	return fmt.Sprintf("0x%s", address)
}

// FungibleToken returns the FungibleToken contract interface.
func FungibleToken(env templates.Environment) []byte {
	return ftcontracts.FungibleToken(env.ViewResolverAddress, env.BurnerAddress)
}

// FungibleTokenMetadataViews returns the FungibleTokenMetadataViews contract interface.
func FungibleTokenMetadataViews(env templates.Environment) []byte {
	return ftcontracts.FungibleTokenMetadataViews(env.FungibleTokenAddress, env.MetadataViewsAddress, env.ViewResolverAddress)
}

// FungibleTokenSwitchboard returns the FungibleTokenSwitchboard contract interface.
func FungibleTokenSwitchboard(env templates.Environment) []byte {
	return ftcontracts.FungibleTokenSwitchboard(env.FungibleTokenAddress)
}

func NonFungibleToken(env templates.Environment) []byte {
	return nftcontracts.NonFungibleToken(env.ViewResolverAddress)
}

func ViewResolver() []byte {
	return nftcontracts.ViewResolver()
}

func Burner() []byte {
	return ftcontracts.Burner()
}

// MetadataViews returns the MetadataViews contract interface.
func MetadataViews(env templates.Environment) []byte {
	return nftcontracts.MetadataViews(env.FungibleTokenAddress, env.NonFungibleTokenAddress, env.ViewResolverAddress)
}

func CrossVMMetadataViews(env templates.Environment) []byte {
	return nftcontracts.CrossVMMetadataViews(env.ViewResolverAddress, env.EVMAddress)
}

// FlowToken returns the FlowToken contract.
//
// The returned contract will import the FungibleToken contract from the specified address.
func FlowToken(env templates.Environment) []byte {
	code := assets.MustAssetString(flowTokenFilename)

	code = templates.ReplaceAddresses(code, env)

	// Replace the init method storage operations
	code = strings.ReplaceAll(
		code,
		"self.account.",
		"adminAccount.",
	)

	// Replace the init method admin account parameter
	code = strings.ReplaceAll(
		code,
		"init()",
		"init(adminAccount: auth(Storage, Capabilities) &Account)",
	)

	return []byte(code)
}

// FlowFees returns the FlowFees contract.
//
// The returned contract will import the FungibleToken and FlowToken
// contracts from the specified addresses.
func FlowFees(env templates.Environment) []byte {
	code := assets.MustAssetString(flowFeesFilename)

	code = templates.ReplaceAddresses(code, env)

	// Replace the init method storage operations
	code = strings.ReplaceAll(
		code,
		"self.account.storage.save(<-admin, to: /storage/flowFeesAdmin)",
		"adminAccount.storage.save(<-admin, to: /storage/flowFeesAdmin)",
	)

	// Replace the init method admin account parameter
	code = strings.ReplaceAll(
		code,
		"init()",
		"init(adminAccount: auth(SaveValue) &Account)",
	)

	return []byte(code)
}

// FlowStorageFees returns the FlowStorageFees contract
// which imports the fungible token and flow token contracts
func FlowStorageFees(env templates.Environment) []byte {
	code := assets.MustAssetString(storageFeesFilename)

	code = templates.ReplaceAddresses(code, env)

	return []byte(code)
}

// FlowExecutionParameters returns the FlowExecutionParameters contract
func FlowExecutionParameters(env templates.Environment) []byte {
	code := assets.MustAssetString(executionParametersFilename)

	code = templates.ReplaceAddresses(code, env)

	return []byte(code)
}

// FlowServiceAccount returns the FlowServiceAccount contract.
//
// The returned contract will import the FungibleToken, FlowToken, FlowFees, and FlowStorageFees
// contracts from the specified addresses.
func FlowServiceAccount(env templates.Environment) []byte {
	code := assets.MustAssetString(flowServiceAccountFilename)

	if env.FlowExecutionParametersAddress == "" {

		// Remove the import of FlowExecutionParameters
		code = strings.ReplaceAll(
			code,
			"import FlowExecutionParameters from \"FlowExecutionParameters\"",
			"//import FlowExecutionParameters from \"FlowExecutionParameters\"",
		)

		// Replace the metering getter functions
		code = strings.ReplaceAll(
			code,
			"return FlowExecutionParameters.getExecutionEffortWeights()",
			"return self.account.storage.copy<{UInt64: UInt64}>(from: /storage/executionEffortWeights) ?? panic(\"execution effort weights not set yet\")",
		)

		code = strings.ReplaceAll(
			code,
			"return FlowExecutionParameters.getExecutionMemoryWeights()",
			"return self.account.storage.copy<{UInt64: UInt64}>(from: /storage/executionMemoryWeights) ?? panic(\"execution memory weights not set yet\")",
		)

		code = strings.ReplaceAll(
			code,
			"return FlowExecutionParameters.getExecutionMemoryLimit()",
			"return self.account.storage.copy<UInt64>(from: /storage/executionMemoryLimit) ?? panic(\"execution memory limit not set yet\")",
		)
	}

	code = templates.ReplaceAddresses(code, env)

	return []byte(code)
}

// FlowIDTableStaking returns the FlowIDTableStaking contract
func FlowIDTableStaking(env templates.Environment) []byte {
	code := assets.MustAssetString(flowIdentityTableFilename)

	code = templates.ReplaceAddresses(code, env)

	return []byte(code)
}

// FlowStakingProxy returns the StakingProxy contract.
func FlowStakingProxy() []byte {
	return assets.MustAsset(flowStakingProxyFilename)
}

// FlowStakingCollection returns the StakingCollection contract.
func FlowStakingCollection(
	env templates.Environment,
) []byte {
	code := assets.MustAssetString(flowStakingCollectionFilename)

	code = templates.ReplaceAddresses(code, env)

	return []byte(code)
}

// FlowLockedTokens return the LockedTokens contract
//
// Locked Tokens imports FungibleToken, FlowToken, FlowIDTableStaking, StakingProxy, and FlowStorageFees
func FlowLockedTokens(
	env templates.Environment,
) []byte {
	code := assets.MustAssetString(flowLockedTokensFilename)

	code = templates.ReplaceAddresses(code, env)

	return []byte(code)
}

// FlowQC returns the FlowClusterQCs contract.
func FlowQC() []byte {
	return assets.MustAsset(flowQCFilename)
}

// FlowDKG returns the FlowDKG contract.
func FlowDKG() []byte {
	return assets.MustAsset(flowDKGFilename)
}

// FlowEpoch returns the FlowEpoch contract.
func FlowEpoch(env templates.Environment) []byte {
	code := assets.MustAssetString(flowEpochFilename)

	code = templates.ReplaceAddresses(code, env)

	return []byte(code)
}

// NodeVersionBeacon returns the NodeVersionBeacon contract content.
func NodeVersionBeacon() []byte {
	return assets.MustAsset(flowNodeVersionBeaconFilename)
}

func RandomBeaconHistory() []byte {
	return assets.MustAsset(flowRandomBeaconHistoryFilename)
}

// FlowContractAudits returns the deprecated FlowContractAudits contract.
// This contract is no longer used on any network
func FlowContractAudits() []byte {
	return assets.MustAsset(flowContractAuditsFilename)
}

func Crypto() []byte {
	return assets.MustAsset(cryptoFilename)
}

/******************** Test contracts *********************/

// TESTFlowIDTableStaking returns the TestFlowIDTableStaking contract
func TESTFlowIDTableStaking(fungibleTokenAddress, flowTokenAddress string) []byte {
	code := assets.MustAssetString(TESTFlowIdentityTableFilename)

	code = strings.ReplaceAll(code, placeholderFungibleTokenAddress, withHexPrefix(fungibleTokenAddress))
	code = strings.ReplaceAll(code, placeholderFlowTokenAddress, withHexPrefix(flowTokenAddress))

	return []byte(code)
}

// TESTFlowStakingCollection returns the StakingCollection contract with all public fields and functions.
func TESTFlowStakingCollection(
	fungibleTokenAddress,
	flowTokenAddress,
	idTableAddress,
	stakingProxyAddress,
	lockedTokensAddress,
	storageFeesAddress,
	qcAddress,
	dkgAddress,
	epochAddress string,
) []byte {
	code := assets.MustAssetString(flowStakingCollectionFilename)

	code = strings.ReplaceAll(code, placeholderFungibleTokenAddress, withHexPrefix(fungibleTokenAddress))
	code = strings.ReplaceAll(code, placeholderBurnerAddress, withHexPrefix(storageFeesAddress))
	code = strings.ReplaceAll(code, placeholderFlowTokenAddress, withHexPrefix(flowTokenAddress))
	code = strings.ReplaceAll(code, placeholderIDTableAddress, withHexPrefix(idTableAddress))
	code = strings.ReplaceAll(code, placeholderStakingProxyAddress, withHexPrefix(stakingProxyAddress))
	code = strings.ReplaceAll(code, placeholderLockedTokensAddress, withHexPrefix(lockedTokensAddress))
	code = strings.ReplaceAll(code, placeholderStorageFeesAddress, withHexPrefix(storageFeesAddress))
	code = strings.ReplaceAll(code, placeholderQCAddr, withHexPrefix(qcAddress))
	code = strings.ReplaceAll(code, placeholderDKGAddr, withHexPrefix(dkgAddress))
	code = strings.ReplaceAll(code, placeholderEpochAddr, withHexPrefix(epochAddress))

	code = strings.ReplaceAll(code, "access(self) fun getTokens", "access(all) fun getTokens")
	code = strings.ReplaceAll(code, "access(self) fun depositTokens", "access(all) fun depositTokens")

	return []byte(code)
}

func TestFlowFees(fungibleTokenAddress, flowTokenAddress, storageFeesAddress string) []byte {
	code := assets.MustAssetString(flowFeesFilename)

	code = strings.ReplaceAll(
		code,
		placeholderFungibleTokenAddress,
		withHexPrefix(fungibleTokenAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderFlowTokenAddress,
		withHexPrefix(flowTokenAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderStorageFeesAddress,
		withHexPrefix(storageFeesAddress),
	)

	return []byte(code)
}
