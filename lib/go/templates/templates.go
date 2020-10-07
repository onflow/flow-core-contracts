package templates

import (
	"fmt"
	"strings"
)

const (
	placeholderFungibleTokenAddress = "0xFUNGIBLETOKENADDRESS"
	placeholderFlowTokenAddress     = "0xFLOWTOKENADDRESS"
	placeholderIDTableAddress       = "0xIDENTITYTABLEADDRESS"
	placeholderStakingProxyAddress  = "0xSTAKINGPROXYADDRESS"
	placeholderLockedTokensAddress  = "0xLOCKEDTOKENADDRESS"
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

// ReplaceAddresses replaces the import address
// and phase in scripts that return info about a specific node and phase
func ReplaceAddresses(
	code,
	fungibleTokenAddress,
	flowTokenAddress,
	idTableAddress string,
) string {

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
		placeholderIDTableAddress,
		withHexPrefix(idTableAddress),
	)

	return code
}

// ReplaceStakingProxyAddress replaces the import address
// and phase in scripts that use staking proxy contract
func ReplaceStakingProxyAddress(code, proxyAddress string) string {

	code = strings.ReplaceAll(
		code,
		placeholderStakingProxyAddress,
		withHexPrefix(proxyAddress),
	)

	return code
}

// ReplaceLockedTokensAddress replaces the import address
// and phase in scripts that return info about a specific node and phase.
func ReplaceLockedTokensAddress(code, lockedTokensAddress string) string {

	code = strings.ReplaceAll(
		code,
		placeholderLockedTokensAddress,
		withHexPrefix(lockedTokensAddress),
	)

	return code
}
