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

	/// Test contracts
	TESTFlowIdentityTableFilename = "../../../contracts/testContracts/TestFlowIDTableStaking.cdc"

	defaultFungibleTokenAddr = "0xFUNGIBLETOKENADDRESS"
	defaultFlowTokenAddr     = "0xFLOWTOKENADDRESS"
	defaultIDTableAddr       = "0xFLOWIDTABLESTAKINGADDRESS"
	defaultStakingProxyAddr  = "0xSTAKINGPROXYADDRESS"
	defaultQCAddr            = "0xQCADDRESS"
	defaultDKGAddr           = "0xDKGADDRESS"
	defaultFlowFeesAddr      = "0xe5a8b7f23e8b548f"
)

func sanitizeAddress(address string) string {
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
func FlowToken(fungibleTokenAddr string) []byte {
	code := assets.MustAssetString(flowTokenFilename)

	code = strings.ReplaceAll(
		code,
		defaultFungibleTokenAddr,
		sanitizeAddress(fungibleTokenAddr),
	)

	return []byte(code)
}

// FlowFees returns the FlowFees contract.
//
// The returned contract will import the FungibleToken and FlowToken
// contracts from the specified addresses.
func FlowFees(fungibleTokenAddr, flowTokenAddr string) []byte {
	code := assets.MustAssetString(flowFeesFilename)

	code = strings.ReplaceAll(
		code,
		defaultFungibleTokenAddr,
		sanitizeAddress(fungibleTokenAddr),
	)

	code = strings.ReplaceAll(
		code,
		defaultFlowTokenAddr,
		sanitizeAddress(flowTokenAddr),
	)

	return []byte(code)
}

// FlowServiceAccount returns the FlowServiceAccount contract.
//
// The returned contract will import the FungibleToken, FlowToken and FlowFees
// contracts from the specified addresses.
func FlowServiceAccount(fungibleTokenAddr, flowTokenAddr, flowFeesAddr string) []byte {
	code := assets.MustAssetString(flowServiceAccountFilename)

	code = strings.ReplaceAll(
		code,
		defaultFungibleTokenAddr,
		sanitizeAddress(fungibleTokenAddr),
	)

	code = strings.ReplaceAll(
		code,
		defaultFlowTokenAddr,
		sanitizeAddress(flowTokenAddr),
	)

	code = strings.ReplaceAll(
		code,
		defaultFlowFeesAddr,
		sanitizeAddress(flowFeesAddr),
	)

	return []byte(code)
}

// FlowIDTableStaking returns the FlowIDTableStaking contract
func FlowIDTableStaking(ftAddr, flowTokenAddr string) []byte {
	code := assets.MustAssetString(flowIdentityTableFilename)

	code = strings.ReplaceAll(code, defaultFungibleTokenAddr, sanitizeAddress(ftAddr))
	code = strings.ReplaceAll(code, defaultFlowTokenAddr, sanitizeAddress(flowTokenAddr))

	return []byte(code)
}

// TESTFlowIDTableStaking returns the TestFlowIDTableStaking contract
func TESTFlowIDTableStaking(ftAddr, flowTokenAddr string) []byte {
	code := assets.MustAssetString(TESTFlowIdentityTableFilename)

	code = strings.ReplaceAll(code, defaultFungibleTokenAddr, sanitizeAddress(ftAddr))
	code = strings.ReplaceAll(code, defaultFlowTokenAddr, sanitizeAddress(flowTokenAddr))

	return []byte(code)
}

// FlowStakingProxy returns the StakingProxy contract.
func FlowStakingProxy() []byte {
	code := assets.MustAssetString(flowStakingProxyFilename)

	return []byte(code)
}

// FlowLockedTokens return the LockedTokens contract
func FlowLockedTokens(ftAddr, flowTokenAddr, idTableAddr, stakingProxyAddr string) []byte {
	code := assets.MustAssetString(flowLockedTokensFilename)

	code = strings.ReplaceAll(code, defaultFungibleTokenAddr, sanitizeAddress(ftAddr))
	code = strings.ReplaceAll(code, defaultFlowTokenAddr, sanitizeAddress(flowTokenAddr))
	code = strings.ReplaceAll(code, defaultIDTableAddr, sanitizeAddress(idTableAddr))
	code = strings.ReplaceAll(code, defaultStakingProxyAddr, sanitizeAddress(stakingProxyAddr))

	return []byte(code)
}
