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
	placeholderNonFungibleTokenAddress    = "\"NonFungibleToken\""
	placeholderEVMAddress                 = "\"EVM\""
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
	EVMAddress                        string
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

func ReplaceAddress(code, placeholder, replacement string) string {
	placeholderWithoutQuotes := placeholder[1 : len(placeholder)-1]

	if len(replacement) > 0 {
		if strings.Contains(code, placeholderWithoutQuotes+" from "+placeholder) {
			code = strings.ReplaceAll(
				code,
				placeholder,
				withHexPrefix(replacement),
			)
		} else {
			code = strings.ReplaceAll(
				code,
				placeholder,
				placeholderWithoutQuotes+" from "+withHexPrefix(replacement),
			)
		}
	}
	return code
}

func ReplaceAddresses(code string, env Environment) string {

	code = ReplaceAddress(
		code,
		placeholderFungibleTokenMVAddress,
		env.FungibleTokenMetadataViewsAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderMetadataViewsAddress,
		env.MetadataViewsAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderBurnerAddress,
		env.BurnerAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderCryptoAddress,
		env.CryptoAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderViewResolverAddress,
		env.ViewResolverAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderFungibleTokenAddress,
		env.FungibleTokenAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderNonFungibleTokenAddress,
		env.NonFungibleTokenAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderEVMAddress,
		env.EVMAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderFlowTokenAddress,
		env.FlowTokenAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderIDTableAddress,
		env.IDTableAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderLockedTokensAddress,
		env.LockedTokensAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderStakingProxyAddress,
		env.StakingProxyAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderQuorumCertificateAddress,
		env.QuorumCertificateAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderDKGAddress,
		env.DkgAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderEpochAddress,
		env.EpochAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderStorageFeesAddress,
		env.StorageFeesAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderFlowFeesAddress,
		env.FlowFeesAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderStakingCollectionAddress,
		env.LockedTokensAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderExecutionParametersAddress,
		env.FlowExecutionParametersAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderServiceAccountAddress,
		env.ServiceAccountAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderNodeVersionBeaconAddress,
		env.NodeVersionBeaconAddress,
	)

	code = ReplaceAddress(
		code,
		placeholderRandomBeaconHistoryAddress,
		env.RandomBeaconHistoryAddress,
	)

	return code
}
