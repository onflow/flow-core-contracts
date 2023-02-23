package templates

//go:generate go run github.com/kevinburke/go-bindata/go-bindata -prefix ../../../transactions -o internal/assets/assets.go -pkg assets -nometadata -nomemcopy ../../../transactions/...
//go:generate go run ./cmd/manifest/main.go ./cmd/manifest/manifest.go manifest.testnet.json --network testnet
//go:generate go run ./cmd/manifest/main.go ./cmd/manifest/manifest.go manifest.mainnet.json --network mainnet

import (
	"fmt"
	"strings"

	_ "github.com/kevinburke/go-bindata"
	_ "github.com/psiemens/sconfig"
	_ "github.com/spf13/cobra"
)

const (
	placeholderFungibleTokenAddress     = "0xFUNGIBLETOKENADDRESS"
	placeholderFlowTokenAddress         = "0xFLOWTOKENADDRESS"
	placeholderIDTableAddress           = "0xIDENTITYTABLEADDRESS"
	placeholderLockedTokensAddress      = "0xLOCKEDTOKENADDRESS"
	placeholderStakingProxyAddress      = "0xSTAKINGPROXYADDRESS"
	placeholderQuorumCertificateAddress = "0xQCADDRESS"
	placeholderFlowFeesAddress          = "0xFLOWFEESADDRESS"
	placeholderStorageFeesAddress       = "0xFLOWSTORAGEFEESADDRESS"
	placeholderServiceAccountAddress    = "0xFLOWSERVICEADDRESS"
	placeholderDKGAddress               = "0xDKGADDRESS"
	placeholderEpochAddress             = "0xEPOCHADDRESS"
	placeholderStakingCollectionAddress = "0xSTAKINGCOLLECTIONADDRESS"
	placeholderNodeVersionBeaconAddress = "0xNODEVERSIONBEACONADDRESS"
)

type Environment struct {
	Network                  string
	FungibleTokenAddress     string
	FlowTokenAddress         string
	IDTableAddress           string
	LockedTokensAddress      string
	StakingProxyAddress      string
	QuorumCertificateAddress string
	DkgAddress               string
	EpochAddress             string
	StorageFeesAddress       string
	FlowFeesAddress          string
	ServiceAccountAddress    string
	NodeVersionBeaconAddress string
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

func ReplaceAddresses(code string, env Environment) string {

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
		placeholderQuorumCertificateAddress,
		withHexPrefix(env.QuorumCertificateAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderDKGAddress,
		withHexPrefix(env.DkgAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderEpochAddress,
		withHexPrefix(env.EpochAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderStorageFeesAddress,
		withHexPrefix(env.StorageFeesAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderFlowFeesAddress,
		withHexPrefix(env.FlowFeesAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderStakingCollectionAddress,
		withHexPrefix(env.LockedTokensAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderServiceAccountAddress,
		withHexPrefix(env.ServiceAccountAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderNodeVersionBeaconAddress,
		withHexPrefix(env.NodeVersionBeaconAddress),
	)

	return code
}
