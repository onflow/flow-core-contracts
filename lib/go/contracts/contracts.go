package contracts

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../../contracts -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../contracts/...

import (
	"fmt"
	"strings"

	ftcontracts "github.com/onflow/flow-ft/lib/go/contracts"

	"github.com/onflow/flow-core-contracts/lib/go/contracts/internal/assets"
)

const (
	flowFeesFilename           = "FlowFees.cdc"
	storageFeesFilename        = "FlowStorageFees.cdc"
	flowServiceAccountFilename = "FlowServiceAccount.cdc"
	flowTokenFilename          = "FlowToken.cdc"
	flowIdentityTableFilename  = "FlowIDTableStaking.cdc"
	flowQCFilename             = "epochs/FlowEpochClusterQC.cdc"
	flowDKGFilename            = "epochs/FlowDKG.cdc"
	flowEpochFilename          = "epochs/FlowEpoch.cdc"
	flowLockedTokensFilename   = "LockedTokens.cdc"
	flowStakingProxyFilename   = "StakingProxy.cdc"

	// Test contracts
	TESTFlowIdentityTableFilename = "testContracts/TestFlowIDTableStaking.cdc"

	placeholderFungibleTokenAddress = "0xFUNGIBLETOKENADDRESS"
	placeholderFlowTokenAddress     = "0xFLOWTOKENADDRESS"
	placeholderIDTableAddress       = "0xFLOWIDTABLESTAKINGADDRESS"
	placeholderStakingProxyAddress  = "0xSTAKINGPROXYADDRESS"
	placeholderQCAddr               = "0xQCADDRESS"
	placeholderDKGAddr              = "0xDKGADDRESS"
	placeholderEpochsAddr           = "0xEPOCHADDRESS"
	placeholderFlowFeesAddress      = "0xFLOWFEESADDRESS"
	placeholderStorageFeesAddress   = "0xFLOWSTORAGEFEESADDRESS"
)

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
func FlowFees(fungibleTokenAddress, flowTokenAddress string) []byte {
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

	return []byte(code)
}

// FlowStorageFees returns the FlowStorageFees contract.
//
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
// The returned contract will import the FungibleToken, FlowToken and FlowFees
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
func FlowIDTableStaking(fungibleTokenAddress, flowTokenAddress string) []byte {
	code := assets.MustAssetString(flowIdentityTableFilename)

	code = strings.ReplaceAll(code, placeholderFungibleTokenAddress, withHexPrefix(fungibleTokenAddress))
	code = strings.ReplaceAll(code, placeholderFlowTokenAddress, withHexPrefix(flowTokenAddress))

	return []byte(code)
}

// TESTFlowIDTableStaking returns the TestFlowIDTableStaking contract
func TESTFlowIDTableStaking(fungibleTokenAddress, flowTokenAddress string) []byte {
	code := assets.MustAssetString(TESTFlowIdentityTableFilename)

	code = strings.ReplaceAll(code, placeholderFungibleTokenAddress, withHexPrefix(fungibleTokenAddress))
	code = strings.ReplaceAll(code, placeholderFlowTokenAddress, withHexPrefix(flowTokenAddress))

	return []byte(code)
}

// FlowStakingProxy returns the StakingProxy contract.
func FlowStakingProxy() []byte {
	code := assets.MustAssetString(flowStakingProxyFilename)

	return []byte(code)
}

// FlowLockedTokens return the LockedTokens contract
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

// FlowQC returns the FlowEpochClusterQCs contract.
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
) []byte {
	code := assets.MustAssetString(flowEpochFilename)

	code = strings.ReplaceAll(code, placeholderFungibleTokenAddress, withHexPrefix(fungibleTokenAddress))
	code = strings.ReplaceAll(code, placeholderFlowTokenAddress, withHexPrefix(flowTokenAddress))
	code = strings.ReplaceAll(code, placeholderIDTableAddress, withHexPrefix(idTableAddress))
	code = strings.ReplaceAll(code, placeholderQCAddr, withHexPrefix(qcAddress))
	code = strings.ReplaceAll(code, placeholderDKGAddr, withHexPrefix(dkgAddress))

	return []byte(code)
}
