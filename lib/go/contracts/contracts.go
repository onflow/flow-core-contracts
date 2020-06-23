package contracts

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../../contracts -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../contracts

import (
	"github.com/onflow/flow-core-contracts/lib/go/contracts/internal/assets"
)

const (
	flowFeesFilename           = "FlowFees.cdc"
	flowServiceAccountFilename = "FlowServiceAccount.cdc"
	flowTokenFilename          = "FlowToken.cdc"
	hexPrefix                  = "0x"
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
