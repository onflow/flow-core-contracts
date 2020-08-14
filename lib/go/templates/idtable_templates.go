package templates

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	currentTableFilename      = "idTable/get_current_table.cdc"
	previousTableFilename     = "idTable/get_previous_table.cdc"
	proposedTableFilename     = "idTable/get_proposed_table.cdc"
	createNodeStructFilename  = "idTable/create_node.cdc"
	removeNodeFilename        = "idTable/remove_node.cdc"
	updateTableFilename       = "idTable/update_table.cdc"
	getRoleFilename           = "idTable/get_node_role.cdc"
	getNetworkingAddrFilename = "idTable/get_node_networking_addr.cdc"
	getNetworkingKeyFilename  = "idTable/get_node_networking_key.cdc"
	getStakingKeyFilename     = "idTable/get_node_staking_key.cdc"
	getInitialWeightFilename  = "idTable/get_node_initial_weight.cdc"
	changeWeightFilename      = "idTable/change_initial_weight.cdc"

	defaultIDTableAddress = "IDENTITYTABLEADDRESS"
)

// ReplaceAddressAndPhase replaces the import address
// and phase in scripts that return info about a specific node and phase
func ReplaceAddressAndPhase(code, tableAddr, phase string) string {

	code = strings.ReplaceAll(
		code,
		"0x"+defaultIDTableAddress,
		"0x"+tableAddr,
	)

	code = strings.ReplaceAll(
		code,
		"{EPOCHPHASE}",
		phase,
	)

	return code
}

// GenerateReturnCurrentTableScript creates a script that returns
// the current ID table
func GenerateReturnCurrentTableScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + currentTableFilename)

	return []byte(ReplaceAddressAndPhase(code, tableAddr, ""))
}

// GenerateReturnPreviousTableScript creates a script that returns
// the ID table from the previous epoch
func GenerateReturnPreviousTableScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + previousTableFilename)

	return []byte(ReplaceAddressAndPhase(code, tableAddr, ""))
}

// GenerateReturnProposedTableScript creates a script that returns
// the ID table for the proposed next epoch
func GenerateReturnProposedTableScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + proposedTableFilename)

	return []byte(ReplaceAddressAndPhase(code, tableAddr, ""))
}

// GenerateCreateNodeScript creates a script that creates a new
// node struct and stores it in the proposed table
func GenerateCreateNodeScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + createNodeStructFilename)

	return []byte(ReplaceAddressAndPhase(code, tableAddr, ""))
}

// GenerateRemoveNodeScript creates a script that removes a node
// from the record
func GenerateRemoveNodeScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + removeNodeFilename)

	return []byte(ReplaceAddressAndPhase(code, tableAddr, ""))
}

// GenerateChangeWeightScript creates a script that removes a node
// from the record
func GenerateChangeWeightScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + changeWeightFilename)

	return []byte(ReplaceAddressAndPhase(code, tableAddr, ""))
}

// GenerateUpdateTableScript creates a script
// that updates the node tables
func GenerateUpdateTableScript(tableAddr string) []byte {
	code := assets.MustAssetString(filePath + updateTableFilename)

	return []byte(ReplaceAddressAndPhase(code, tableAddr, ""))
}

// GenerateGetRoleScript creates a script
// that returns the role of a node
func GenerateGetRoleScript(tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getRoleFilename)

	return []byte(ReplaceAddressAndPhase(code, tableAddr, phase))
}

// GenerateGetNetworkingAddressScript creates a script
// that returns the networking address of a node
func GenerateGetNetworkingAddressScript(tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getNetworkingAddrFilename)

	return []byte(ReplaceAddressAndPhase(code, tableAddr, phase))
}

// GenerateGetNetworkingKeyScript creates a script
// that returns the networking key of a node
func GenerateGetNetworkingKeyScript(tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getNetworkingKeyFilename)

	return []byte(ReplaceAddressAndPhase(code, tableAddr, phase))
}

// GenerateGetStakingKeyScript creates a script
// that returns the staking key of a node
func GenerateGetStakingKeyScript(tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getStakingKeyFilename)

	return []byte(ReplaceAddressAndPhase(code, tableAddr, phase))
}

// GenerateGetInitialWeightScript creates a script
// that returns the initial weight of a node
func GenerateGetInitialWeightScript(tableAddr, phase string) []byte {
	code := assets.MustAssetString(filePath + getInitialWeightFilename)

	return []byte(ReplaceAddressAndPhase(code, tableAddr, phase))
}
