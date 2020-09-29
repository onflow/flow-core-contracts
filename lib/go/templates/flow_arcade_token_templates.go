package templates

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	addMinterFilename             = "flowArcadeToken/admin/add_minter.cdc"
	deployFlowArcadeTokenFilename = "flowArcadeToken/admin/deploy_flow_arcade_token.cdc"
	mintTokensFilename            = "flowArcadeToken/mint_tokens.cdc"
	setupAccountFilename          = "flowArcadeToken/setup_account.cdc"
	transferTokensFilename        = "flowArcadeToken/transfer_tokens.cdc"

	getBalanceFilename = "flowArcadeToken/scripts/get_balance.cdc"
	getSupplyFilename  = "flowArcadeToken/scripts/get_supply.cdc"

	defaultFungibleTokenAddress   = "FUNGIBLETOKENADDRESS"
	defaultFlowArcadeTokenAddress = "ARCADETOKENADDRESS"
)

// ReplaceAddresses replaces the contract addresses in the code
func replaceAddresses(code, ftAddr, fatAddr string) string {

	code = strings.ReplaceAll(
		code,
		"0x"+defaultFungibleTokenAddress,
		"0x"+ftAddr,
	)

	code = strings.ReplaceAll(
		code,
		"0x"+defaultFlowArcadeTokenAddress,
		"0x"+fatAddr,
	)

	return code
}

func GenerateDeployFlowArcadeTokenScript() []byte {
	code := assets.MustAssetString(filePath + deployFlowArcadeTokenFilename)

	return []byte(code)
}

func GenerateAddMinterScript(fatAddr string) []byte {
	code := assets.MustAssetString(filePath + addMinterFilename)

	return []byte(replaceAddresses(code, "", fatAddr))
}

func GenerateSetupAccountScript(ftAddr, fatAddr string) []byte {
	code := assets.MustAssetString(filePath + setupAccountFilename)

	return []byte(replaceAddresses(code, ftAddr, fatAddr))
}

func GenerateMintTokensScript(ftAddr, fatAddr string) []byte {
	code := assets.MustAssetString(filePath + mintTokensFilename)

	return []byte(replaceAddresses(code, ftAddr, fatAddr))
}

func GenerateTransferTokensScript(ftAddr, fatAddr string) []byte {
	code := assets.MustAssetString(filePath + transferTokensFilename)

	return []byte(replaceAddresses(code, ftAddr, fatAddr))
}

func GenerateGetBalanceScript(ftAddr, fatAddr string) []byte {
	code := assets.MustAssetString(filePath + getBalanceFilename)

	return []byte(replaceAddresses(code, ftAddr, fatAddr))
}

func GenerateGetSupplyScript(fatAddr string) []byte {
	code := assets.MustAssetString(filePath + getSupplyFilename)

	return []byte(replaceAddresses(code, "", fatAddr))
}
