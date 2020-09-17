package contracts

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../../contracts/... -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../contracts/...

import (
	"strings"

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

	hexPrefix                = "0x"
	defaultFungibleTokenAddr = "FUNGIBLETOKENADDRESS"
	defaultFlowTokenAddr     = "FLOWTOKENADDRESS"
	defaultIDTableAddr       = "FLOWIDTABLESTAKINGADDRESS"
	defaultQCAddr            = "QCADDRESS"
	defaultDKGAddr           = "DKGADDRESS"
)

// FlowToken returns the FlowToken contract. importing the
//
// The returned contract will import the FungibleToken contract from the specified address.
func FlowToken() []byte {
	code := assets.MustAssetString(flowTokenFilename)
	return []byte(code)
}

// FlowFees returns the FlowFees contract.
//
// The returned contract imports the FungibleToken and FlowToken
// contracts from the default addresses.
func FlowFees() []byte {
	code := assets.MustAssetString(flowFeesFilename)

	return []byte(code)
}

// FlowServiceAccount returns the FlowServiceAccount contract.
//
// The returned contract imports the FungibleToken, FlowToken and FlowFees
// contracts from the default addresses.
func FlowServiceAccount() []byte {
	code := assets.MustAssetString(flowServiceAccountFilename)

	return []byte(code)
}

// FlowIDTableStaking returns the FlowIDTableStaking contract
func FlowIDTableStaking(ftAddr, flowTokenAddr string) []byte {
	code := assets.MustAssetString(flowIdentityTableFilename)

	code = strings.ReplaceAll(code, defaultFungibleTokenAddr, ftAddr)
	code = strings.ReplaceAll(code, defaultFlowTokenAddr, flowTokenAddr)

	return []byte(code)
}
