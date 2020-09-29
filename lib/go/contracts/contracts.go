package contracts

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../../contracts/... -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../contracts/...

import (
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
	flowArcadeTokenFilename    = "../../../contracts/FlowArcadeToken.cdc"

	hexPrefix                  = "0x"
	defaultFungibleTokenAddr   = "FUNGIBLETOKENADDRESS"
	defaultFlowTokenAddr       = "FLOWTOKENADDRESS"
	defaultIDTableAddr         = "FLOWIDTABLESTAKINGADDRESS"
	defaultQCAddr              = "QCADDRESS"
	defaultDKGAddr             = "DKGADDRESS"
	defaultFlowFeesAddr        = "0xe5a8b7f23e8b548f"
	defaultFlowArcadeTokenAddr = "FLOWARCADETOKENADDRESS"
)

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
		fungibleTokenAddr,
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
		fungibleTokenAddr,
	)

	code = strings.ReplaceAll(
		code,
		defaultFlowTokenAddr,
		flowTokenAddr,
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
		fungibleTokenAddr,
	)

	code = strings.ReplaceAll(
		code,
		defaultFlowTokenAddr,
		flowTokenAddr,
	)

	code = strings.ReplaceAll(
		code,
		defaultFlowFeesAddr,
		flowFeesAddr,
	)

	return []byte(code)
}

// FlowIDTableStaking returns the FlowIDTableStaking contract
func FlowIDTableStaking(ftAddr, flowTokenAddr string) []byte {
	code := assets.MustAssetString(flowIdentityTableFilename)

	code = strings.ReplaceAll(code, defaultFungibleTokenAddr, ftAddr)
	code = strings.ReplaceAll(code, defaultFlowTokenAddr, flowTokenAddr)

	return []byte(code)
}

// FlowArcadeToken returns the FlowArcadeToken contract.
//
// The returned contract will import the FungibleToken contract from the specified address.
func FlowArcadeToken(fungibleTokenAddr string) []byte {
	code := assets.MustAssetString(flowArcadeTokenFilename)

	code = strings.ReplaceAll(
		code,
		defaultFungibleTokenAddr,
		fungibleTokenAddr,
	)

	return []byte(code)
}
