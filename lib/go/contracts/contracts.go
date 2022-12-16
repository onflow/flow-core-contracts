package contracts

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../../contracts -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../contracts/...

import (
	"fmt"
	"strings"

	_ "github.com/kevinburke/go-bindata"
	ftcontracts "github.com/onflow/flow-ft/lib/go/contracts"

	"github.com/onflow/flow-core-contracts/lib/go/contracts/internal/assets"
)

/// This package contains utility functions to get contract code for the contracts in this repo
/// To use this package, import the `flow-core-contracts/lib/go/contracts` package,
/// then use the contracts package to call one of these functions.
/// They will return the byte array version of the contract.
///
/// Example
///
/// flowTokenCode := contracts.FlowToken(fungibleTokenAddr)
///

const (
	flowFeesFilename              = "FlowFees.cdc"
	storageFeesFilename           = "FlowStorageFees.cdc"
	flowServiceAccountFilename    = "FlowServiceAccount.cdc"
	flowTokenFilename             = "FlowToken.cdc"
	flowIdentityTableFilename     = "FlowIDTableStaking.cdc"
	flowQCFilename                = "epochs/FlowClusterQC.cdc"
	flowDKGFilename               = "epochs/FlowDKG.cdc"
	flowEpochFilename             = "epochs/FlowEpoch.cdc"
	flowLockedTokensFilename      = "LockedTokens.cdc"
	flowStakingProxyFilename      = "StakingProxy.cdc"
	flowStakingCollectionFilename = "FlowStakingCollection.cdc"
	flowContractAuditsFilename    = "FlowContractAudits.cdc"
	flowNodeVersionBeaconFilename = "NodeVersionBeacon.cdc"

	// Test contracts
	// only used for testing
	TESTFlowIdentityTableFilename = "testContracts/TestFlowIDTableStaking.cdc"

	// Each contract has placeholder addresses that need to be replaced
	// depending on which network they are being used with
	placeholderFungibleTokenAddress     = "0xFUNGIBLETOKENADDRESS"
	placeholderFlowTokenAddress         = "0xFLOWTOKENADDRESS"
	placeholderIDTableAddress           = "0xFLOWIDTABLESTAKINGADDRESS"
	placeholderStakingProxyAddress      = "0xSTAKINGPROXYADDRESS"
	placeholderQCAddr                   = "0xQCADDRESS"
	placeholderDKGAddr                  = "0xDKGADDRESS"
	placeholderEpochAddr                = "0xEPOCHADDRESS"
	placeholderFlowFeesAddress          = "0xFLOWFEESADDRESS"
	placeholderStorageFeesAddress       = "0xFLOWSTORAGEFEESADDRESS"
	placeholderLockedTokensAddress      = "0xLOCKEDTOKENSADDRESS"
	placeholderStakingCollectionAddress = "0xFLOWSTAKINGCOLLECTIONADDRESS"
	placeholderNodeVersionBeaconAddress = "0xNODEVERSIONBEACONADDRESS"
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
func FungibleToken() []byte {
	return ftcontracts.FungibleToken()
}

// FlowToken returns the FlowToken contract.
//
// The returned contract will import the FungibleToken contract from the specified address.
func FlowToken(fungibleTokenAddress string) []byte {
	code := assets.MustAssetString(flowTokenFilename)

	// Replace the fungible token placeholder address
	// with the provided address
	code = strings.ReplaceAll(
		code,
		placeholderFungibleTokenAddress,
		withHexPrefix(fungibleTokenAddress),
	)

	return []byte(code)
}

// FlowFees returns the FlowFees contract.
//
// The returned contract will import the FungibleToken and FlowToken
// contracts from the specified addresses.
func FlowFees(fungibleTokenAddress, flowTokenAddress, storageFees string) []byte {
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
		withHexPrefix(storageFees),
	)

	return []byte(code)
}

// FlowStorageFees returns the FlowStorageFees contract
// which imports the fungible token and flow token contracts
func FlowStorageFees(fungibleTokenAddress, flowTokenAddress string) []byte {
	code := assets.MustAssetString(storageFeesFilename)

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

	return []byte(code)
}

// FlowServiceAccount returns the FlowServiceAccount contract.
//
// The returned contract will import the FungibleToken, FlowToken, FlowFees, and FlowStorageFees
// contracts from the specified addresses.
func FlowServiceAccount(fungibleTokenAddress, flowTokenAddress, flowFeesAddress, storageFeesAddress string) []byte {
	code := assets.MustAssetString(flowServiceAccountFilename)

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
		placeholderFlowFeesAddress,
		withHexPrefix(flowFeesAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderStorageFeesAddress,
		withHexPrefix(storageFeesAddress),
	)

	return []byte(code)
}

// FlowIDTableStaking returns the FlowIDTableStaking contract
//
// # The staking contract imports the FungibleToken and FlowToken contracts
//
// Parameter: latest: indicates if the contract is the latest version, or an old version. Used to test upgrades
func FlowIDTableStaking(fungibleTokenAddress, flowTokenAddress, flowFeesAddress string, latest bool) []byte {
	var code string

	if latest {
		code = assets.MustAssetString(flowIdentityTableFilename)
	} else {
		code = assets.MustAssetString("FlowIDTableStaking_old.cdc")
	}

	code = strings.ReplaceAll(code, placeholderFungibleTokenAddress, withHexPrefix(fungibleTokenAddress))
	code = strings.ReplaceAll(code, placeholderFlowTokenAddress, withHexPrefix(flowTokenAddress))
	code = strings.ReplaceAll(code, placeholderFlowFeesAddress, withHexPrefix(flowFeesAddress))

	return []byte(code)
}

// FlowStakingProxy returns the StakingProxy contract.
func FlowStakingProxy() []byte {
	code := assets.MustAssetString(flowStakingProxyFilename)
	return []byte(code)
}

// FlowStakingCollection returns the StakingCollection contract.
func FlowStakingCollection(
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
	code = strings.ReplaceAll(code, placeholderFlowTokenAddress, withHexPrefix(flowTokenAddress))
	code = strings.ReplaceAll(code, placeholderIDTableAddress, withHexPrefix(idTableAddress))
	code = strings.ReplaceAll(code, placeholderStakingProxyAddress, withHexPrefix(stakingProxyAddress))
	code = strings.ReplaceAll(code, placeholderLockedTokensAddress, withHexPrefix(lockedTokensAddress))
	code = strings.ReplaceAll(code, placeholderStorageFeesAddress, withHexPrefix(storageFeesAddress))
	code = strings.ReplaceAll(code, placeholderQCAddr, withHexPrefix(qcAddress))
	code = strings.ReplaceAll(code, placeholderDKGAddr, withHexPrefix(dkgAddress))
	code = strings.ReplaceAll(code, placeholderEpochAddr, withHexPrefix(epochAddress))

	return []byte(code)
}

// FlowLockedTokens return the LockedTokens contract
//
// Locked Tokens imports FungibleToken, FlowToken, FlowIDTableStaking, StakingProxy, and FlowStorageFees
func FlowLockedTokens(
	fungibleTokenAddress,
	flowTokenAddress,
	idTableAddress,
	stakingProxyAddress,
	storageFeesAddress string,
) []byte {
	code := assets.MustAssetString(flowLockedTokensFilename)

	code = strings.ReplaceAll(code, placeholderFungibleTokenAddress, withHexPrefix(fungibleTokenAddress))
	code = strings.ReplaceAll(code, placeholderFlowTokenAddress, withHexPrefix(flowTokenAddress))
	code = strings.ReplaceAll(code, placeholderIDTableAddress, withHexPrefix(idTableAddress))
	code = strings.ReplaceAll(code, placeholderStakingProxyAddress, withHexPrefix(stakingProxyAddress))
	code = strings.ReplaceAll(code, placeholderStorageFeesAddress, withHexPrefix(storageFeesAddress))

	return []byte(code)
}

// FlowQC returns the FlowClusterQCs contract.
func FlowQC() []byte {
	code := assets.MustAssetString(flowQCFilename)

	return []byte(code)
}

// FlowDKG returns the FlowDKG contract.
func FlowDKG() []byte {
	code := assets.MustAssetString(flowDKGFilename)

	return []byte(code)
}

// FlowEpoch returns the FlowEpoch contract.
func FlowEpoch(fungibleTokenAddress,
	flowTokenAddress,
	idTableAddress,
	qcAddress,
	dkgAddress string,
	flowFeesAddress string,
) []byte {
	code := assets.MustAssetString(flowEpochFilename)

	code = strings.ReplaceAll(code, placeholderFungibleTokenAddress, withHexPrefix(fungibleTokenAddress))
	code = strings.ReplaceAll(code, placeholderFlowTokenAddress, withHexPrefix(flowTokenAddress))
	code = strings.ReplaceAll(code, placeholderIDTableAddress, withHexPrefix(idTableAddress))
	code = strings.ReplaceAll(code, placeholderQCAddr, withHexPrefix(qcAddress))
	code = strings.ReplaceAll(code, placeholderDKGAddr, withHexPrefix(dkgAddress))
	code = strings.ReplaceAll(code, placeholderFlowFeesAddress, withHexPrefix(flowFeesAddress))

	return []byte(code)
}

// NodeVersionBeacon returns the NodeVersionBeacon contract content.
func NodeVersionBeacon() []byte {
	code := assets.MustAssetString(flowNodeVersionBeaconFilename)

	return []byte(code)
}

// FlowContractAudits returns the FlowContractAudits contract.
func FlowContractAudits() []byte {
	code := assets.MustAssetString(flowContractAuditsFilename)

	return []byte(code)
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
	code = strings.ReplaceAll(code, placeholderFlowTokenAddress, withHexPrefix(flowTokenAddress))
	code = strings.ReplaceAll(code, placeholderIDTableAddress, withHexPrefix(idTableAddress))
	code = strings.ReplaceAll(code, placeholderStakingProxyAddress, withHexPrefix(stakingProxyAddress))
	code = strings.ReplaceAll(code, placeholderLockedTokensAddress, withHexPrefix(lockedTokensAddress))
	code = strings.ReplaceAll(code, placeholderStorageFeesAddress, withHexPrefix(storageFeesAddress))
	code = strings.ReplaceAll(code, placeholderQCAddr, withHexPrefix(qcAddress))
	code = strings.ReplaceAll(code, placeholderDKGAddr, withHexPrefix(dkgAddress))
	code = strings.ReplaceAll(code, placeholderEpochAddr, withHexPrefix(epochAddress))

	code = strings.ReplaceAll(code, "access(self)", "pub")

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

	code = strings.ReplaceAll(
		code,
		"init(adminAccount: AuthAccount)",
		"init()",
	)

	code = strings.ReplaceAll(
		code,
		"adminAccount.save(<-admin, to: /storage/flowFeesAdmin)",
		"self.account.save(<-admin, to: /storage/flowFeesAdmin)",
	)

	return []byte(code)
}
