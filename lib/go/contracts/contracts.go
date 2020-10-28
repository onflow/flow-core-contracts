package contracts

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../../contracts/... -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../contracts/...

import (
	"fmt"
	"strings"

	ftcontracts "github.com/onflow/flow-ft/lib/go/contracts"

	"github.com/onflow/flow-core-contracts/lib/go/contracts/internal/assets"
)

const (
	flowFeesFilename           = "../../../contracts/FlowFees.cdc"
	flowServiceAccountFilename = "../../../contracts/FlowServiceAccount.cdc"
	flowTokenFilename          = "../../../contracts/FlowToken.cdc"
	flowIdentityTableFilename  = "../../../contracts/FlowIDTableStaking.cdc"
	flowQCFilename             = "../../../contracts/epochs/FlowQuorumCertificate.cdc"
	flowDKGFilename            = "../../../contracts/epochs/FlowDKG.cdc"
	flowEpochFilename          = "../../../contracts/epochs/FlowEpoch.cdc"
	flowLockedTokensFilename   = "../../../contracts/LockedTokens.cdc"
	flowStakingProxyFilename   = "../../../contracts/StakingProxy.cdc"

	// Test contracts
	TESTFlowIdentityTableFilename = "../../../contracts/testContracts/TestFlowIDTableStaking.cdc"

	placeholderFungibleTokenAddress = "0xFUNGIBLETOKENADDRESS"
	placeholderFlowTokenAddress     = "0xFLOWTOKENADDRESS"
	placeholderIDTableAddress       = "0xFLOWIDTABLESTAKINGADDRESS"
	placeholderStakingProxyAddress  = "0xSTAKINGPROXYADDRESS"
	placeholderQCAddr               = "0xQCADDRESS"
	placeholderDKGAddr              = "0xDKGADDRESS"
	placeholderFlowFeesAddress      = "0xFLOWFEESADDRESS"
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

// FlowServiceAccount returns the FlowServiceAccount contract.
//
// The returned contract will import the FungibleToken, FlowToken and FlowFees
// contracts from the specified addresses.
func FlowServiceAccount(fungibleTokenAddress, flowTokenAddress, flowFeesAddress string) []byte {
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
	stakingProxyAddress string,
) []byte {
	code := assets.MustAssetString(flowLockedTokensFilename)

	code = strings.ReplaceAll(code, placeholderFungibleTokenAddress, withHexPrefix(fungibleTokenAddress))
	code = strings.ReplaceAll(code, placeholderFlowTokenAddress, withHexPrefix(flowTokenAddress))
	code = strings.ReplaceAll(code, placeholderIDTableAddress, withHexPrefix(idTableAddress))
	code = strings.ReplaceAll(code, placeholderStakingProxyAddress, withHexPrefix(stakingProxyAddress))

	return []byte(code)
}
