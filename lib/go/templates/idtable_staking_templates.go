package templates

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	transferDeployFilename    = "idTableStaking/transfer_minter_deploy.cdc"
	currentTableFilename      = "idTableStaking/get_current_table.cdc"
	proposedTableFilename     = "idTableStaking/get_proposed_table.cdc"
	createNodeStructFilename  = "idTableStaking/create_node.cdc"
	removeNodeFilename        = "idTableStaking/remove_node.cdc"
	updateTableFilename       = "idTableStaking/update_table.cdc"
	getRoleFilename           = "idTableStaking/get_node_role.cdc"
	getNetworkingAddrFilename = "idTableStaking/get_node_networking_addr.cdc"
	getNetworkingKeyFilename  = "idTableStaking/get_node_networking_key.cdc"
	getStakingKeyFilename     = "idTableStaking/get_node_staking_key.cdc"
	getInitialWeightFilename  = "idTableStaking/get_node_initial_weight.cdc"
	changeWeightFilename      = "idTableStaking/change_initial_weight.cdc"

	defaultFTAddress        = "FUNGIBLETOKENADDRESS"
	defaultFlowTokenAddress = "FLOWTOKENADDRESS"
	defaultIDTableAddress   = "IDENTITYTABLEADDRESS"
)

// ReplaceAddressesAndPhase replaces the import address
// and phase in scripts that return info about a specific node and phase
func ReplaceAddressesAndPhase(code, ftAddr, flowTokenAddr, idTableAddr, phase string) string {

	code = strings.ReplaceAll(
		code,
		"0x"+defaultFTAddress,
		"0x"+ftAddr,
	)

	code = strings.ReplaceAll(
		code,
		"0x"+defaultFlowTokenAddress,
		"0x"+flowTokenAddr,
	)

	code = strings.ReplaceAll(
		code,
		"0x"+defaultIDTableAddress,
		"0x"+idTableAddr,
	)

	code = strings.ReplaceAll(
		code,
		"{EPOCHPHASE}",
		phase,
	)

	return code
}

// GenerateTransferMinterAndDeployScript generates a script that transfers
// a flow minter and deploys the id table account
func GenerateTransferMinterAndDeployScript(ftAddr, flowAddr string) []byte {
	code := assets.MustAssetString(filePath + transferDeployFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, "", ""))
}

// GenerateReturnCurrentTableScript creates a script that returns
// the current ID table
func GenerateReturnCurrentTableScript(ftAddr, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + currentTableFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, idTableAddr, ""))
}

// GenerateReturnProposedTableScript creates a script that returns
// the ID table for the proposed next epoch
func GenerateReturnProposedTableScript(ftAddr, flowAddr, idTableAddr string) []byte {
	code := assets.MustAssetString(filePath + proposedTableFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, idTableAddr, ""))
}

// GenerateCreateNodeScript creates a script that creates a new
// node struct and stores it in the Node records
func GenerateCreateNodeScript(ftAddr, flowAddr, tableAddr string) []byte {
	code := assets.MustAssetString(filePath + createNodeStructFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, tableAddr, ""))
}

// GenerateRemoveNodeScript creates a script that removes a node
// from the record
func GenerateRemoveNodeScript(ftAddr, flowAddr, tableAddr string) []byte {
	code := assets.MustAssetString(filePath + removeNodeFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, tableAddr, ""))
}

// GenerateGetRoleScript creates a script
// that returns the role of a node
func GenerateGetRoleScript(ftAddr, flowAddr, tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getRoleFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, tableAddr, phase))
}

// GenerateGetNetworkingAddressScript creates a script
// that returns the networking address of a node
func GenerateGetNetworkingAddressScript(ftAddr, flowAddr, tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getNetworkingAddrFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, tableAddr, phase))
}

// GenerateGetNetworkingKeyScript creates a script
// that returns the networking key of a node
func GenerateGetNetworkingKeyScript(ftAddr, flowAddr, tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getNetworkingKeyFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, tableAddr, phase))
}

// GenerateGetStakingKeyScript creates a script
// that returns the staking key of a node
func GenerateGetStakingKeyScript(ftAddr, flowAddr, tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getStakingKeyFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, tableAddr, phase))
}

// GenerateGetInitialWeightScript creates a script
// that returns the initial weight of a node
func GenerateGetInitialWeightScript(ftAddr, flowAddr, tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getInitialWeightFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, tableAddr, phase))
}

// GenerateGetStakedBalanceScript creates a script
// that returns the balance of the staked tokens of a node
func GenerateGetStakedBalanceScript(ftAddr, flowAddr, tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getInitialWeightFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, tableAddr, phase))
}

// GenerateGetCommittedBalanceScript creates a script
// that returns the balance of the committed tokens of a node
func GenerateGetCommittedBalanceScript(ftAddr, flowAddr, tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getInitialWeightFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, tableAddr, phase))
}

// GenerateGetUnstakedBalanceScript creates a script
// that returns the balance of the unstaked tokens of a node
func GenerateGetUnstakedBalanceScript(ftAddr, flowAddr, tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getInitialWeightFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, tableAddr, phase))
}

// GenerateGetUnlockedBalanceScript creates a script
// that returns the balance of the unlocked tokens of a node
func GenerateGetUnlockedBalanceScript(ftAddr, flowAddr, tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getInitialWeightFilename)

	return []byte(ReplaceAddressesAndPhase(code, ftAddr, flowAddr, tableAddr, phase))
}
