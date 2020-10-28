package templates

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../../transactions/... -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../transactions/...

import (
	"fmt"
	"strings"
)

const (
	placeholderFungibleTokenAddress = "0xFUNGIBLETOKENADDRESS"
	placeholderFlowTokenAddress     = "0xFLOWTOKENADDRESS"
	placeholderIDTableAddress       = "0xIDENTITYTABLEADDRESS"
	placeholderLockedTokensAddress  = "0xLOCKEDTOKENADDRESS"
	placeholderStakingProxyAddress  = "0xSTAKINGPROXYADDRESS"
)

type Environment struct {
	FungibleTokenAddress string
	FlowTokenAddress     string
	IDTableAddress       string
	LockedTokensAddress  string
	StakingProxyAddress  string
}

func withHexPrefix(address string) string {
	if address == "" {
		return ""
	}

	if address[0:2] == "0x" {
		return address
	}

	return fmt.Sprintf("0x%s", address)
}

func replaceAddresses(code string, env Environment) string {

	code = strings.ReplaceAll(
		code,
		placeholderFungibleTokenAddress,
		withHexPrefix(env.FungibleTokenAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderFlowTokenAddress,
		withHexPrefix(env.FlowTokenAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderIDTableAddress,
		withHexPrefix(env.IDTableAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderLockedTokensAddress,
		withHexPrefix(env.LockedTokensAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderStakingProxyAddress,
		withHexPrefix(env.StakingProxyAddress),
	)

	return code
}
