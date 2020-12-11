package templates

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../../transactions/... -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../transactions/...
//go:generate go run ./manifest/main.go ./manifest/manifest.go manifest.testnet.json --network testnet
//go:generate go run ./manifest/main.go ./manifest/manifest.go manifest.mainnet.json --network mainnet

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
	placeholderKeyManagerAddress    = "0xKEYMANAGERADDRESS"
)

type Environment struct {
	Network              string
	FungibleTokenAddress string
	FlowTokenAddress     string
	IDTableAddress       string
	LockedTokensAddress  string
	StakingProxyAddress  string
	KeyManagerAddress    string
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

	code = strings.ReplaceAll(
		code,
		placeholderKeyManagerAddress,
		withHexPrefix(env.KeyManagerAddress),
	)

	return code
}
