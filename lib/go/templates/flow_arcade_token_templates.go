package templates

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	deployFlowArcadeTokenFilename = "flowArcadeToken/admin/deploy_flow_arcade_token.cdc"
	mintTokensFilename            = "flowArcadeToken/admin/mint_tokens.cdc"
	setupAccountFilename          = "flowArcadeToken/setup_account.cdc"
	transferTokensFilename        = "flowArcadeToken/transfer_tokens.cdc"

	getBalanceFilename = "flowArcadeToken/scripts/get_balance.cdc"
	getSupplyFilename  = "flowArcadeToken/scripts/get_supply.cdc"

	placeholderFlowArcadeTokenAddress   = "0xARCADETOKENADDRESS"
	placeholderUniqueMinterPathFragment = "UNIQUEMINTERPATHFRAGMENT"

	placeholderResourceStoragePath   = "/RESOURCESTORAGEPATH"
	placeholderCapabilityPrivatePath = "/CAPABILITYPRIVATEPATH"
)

// ReplaceAddresses replaces the contract addresses in the code
func ReplaceFATAddress(code, fatAddr string) string {
	code = strings.ReplaceAll(
		code,
		placeholderFlowArcadeTokenAddress,
		withHexPrefix(fatAddr),
	)

	return code
}

func GenerateDeployFlowArcadeTokenScript() []byte {
	code := assets.MustAssetString(filePath + deployFlowArcadeTokenFilename)

	return []byte(code)
}

func GenerateSetupAccountScript(ftAddr, fatAddr string) []byte {
	code := assets.MustAssetString(filePath + setupAccountFilename)

	code = ReplaceAddresses(code, ftAddr, "", "")

	code = ReplaceFATAddress(code, fatAddr)

	return []byte(code)
}

func GenerateMintTokensScript(ftAddr, fatAddr string) []byte {
	code := assets.MustAssetString(filePath + mintTokensFilename)

	code = ReplaceAddresses(code, ftAddr, "", "")

	code = ReplaceFATAddress(code, fatAddr)

	return []byte(code)
}

func GenerateTransferTokensScript(ftAddr, fatAddr string) []byte {
	code := assets.MustAssetString(filePath + transferTokensFilename)

	code = ReplaceAddresses(code, ftAddr, "", "")

	code = ReplaceFATAddress(code, fatAddr)

	return []byte(code)
}

func GenerateGetBalanceScript(ftAddr, fatAddr string) []byte {
	code := assets.MustAssetString(filePath + getBalanceFilename)

	code = ReplaceAddresses(code, ftAddr, "", "")

	code = ReplaceFATAddress(code, fatAddr)

	return []byte(code)
}

func GenerateGetSupplyScript(fatAddr string) []byte {
	code := assets.MustAssetString(filePath + getSupplyFilename)

	code = ReplaceFATAddress(code, fatAddr)

	return []byte(code)
}
