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
	placeholderFungibleTokenAddress       = "\"FungibleToken\""
	placeholderViewResolverAddress        = "\"ViewResolver\""
	placeholderFungibleTokenMVAddress     = "\"FungibleTokenMetadataViews\""
	placeholderMetadataViewsAddress       = "\"MetadataViews\""
	placeholderBurnerAddress              = "\"Burner\""
	placeholderCryptoAddress              = "\"Crypto\""
	placeholderFlowTokenAddress           = "\"FlowToken\""
	placeholderIDTableAddress             = "\"FlowIDTableStaking\""
	placeholderLockedTokensAddress        = "\"LockedTokens\""
	placeholderStakingProxyAddress        = "\"StakingProxy\""
	placeholderQuorumCertificateAddress   = "\"FlowClusterQC\""
	placeholderFlowFeesAddress            = "\"FlowFees\""
	placeholderStorageFeesAddress         = "\"FlowStorageFees\""
	placeholderExecutionParametersAddress = "\"FlowExecutionParameters\""
	placeholderServiceAccountAddress      = "\"FlowServiceAccount\""
	placeholderDKGAddress                 = "\"FlowDKG\""
	placeholderEpochAddress               = "\"FlowEpoch\""
	placeholderStakingCollectionAddress   = "\"FlowStakingCollection\""
	placeholderNodeVersionBeaconAddress   = "\"NodeVersionBeacon\""
	placeholderRandomBeaconHistoryAddress = "\"RandomBeaconHistory\""
)

type Environment struct {
	Network                           string
	ViewResolverAddress               string
	BurnerAddress                     string
	CryptoAddress                     string
	FungibleTokenAddress              string
	NonFungibleTokenAddress           string
	MetadataViewsAddress              string
	FungibleTokenMetadataViewsAddress string
	FungibleTokenSwitchboardAddress   string
	FlowTokenAddress                  string
	IDTableAddress                    string
	LockedTokensAddress               string
	StakingProxyAddress               string
	QuorumCertificateAddress          string
	DkgAddress                        string
	EpochAddress                      string
	StorageFeesAddress                string
	FlowFeesAddress                   string
	StakingCollectionAddress          string
	FlowExecutionParametersAddress    string
	ServiceAccountAddress             string
	NodeVersionBeaconAddress          string
	RandomBeaconHistoryAddress        string
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
		placeholderFungibleTokenMVAddress,
		withHexPrefix(env.FungibleTokenMetadataViewsAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderMetadataViewsAddress,
		withHexPrefix(env.MetadataViewsAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderBurnerAddress,
		withHexPrefix(env.BurnerAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderCryptoAddress,
		withHexPrefix(env.CryptoAddress),
	)

	code = strings.ReplaceAll(
		code,
		placeholderViewResolverAddress,
		withHexPrefix(env.ViewResolverAddress),
	)

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
		placeholderExecutionParametersAddress,
		withHexPrefix(env.FlowExecutionParametersAddress),
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

	code = strings.ReplaceAll(
		code,
		placeholderRandomBeaconHistoryAddress,
		withHexPrefix(env.RandomBeaconHistoryAddress),
	)

	return code
}
