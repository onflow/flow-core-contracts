package templates

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (

	// node operator templates
	setupNodeAccountFilename   = "stakingProxy/stakingHelper/sh_setup_node_account_filename.cdc"
	addNodeInfoFilename        = ""
	removeNodeInfoFilename     = ""
	removeStakingProxyFilename = ""

	// templates for node operator doing staking actions
	proxyStakeNewTokensFilename      = ""
	proxyStakeUnlockedTokensFilename = ""
	proxyRequestUnstakingFilename    = ""
	proxyUnstakeAllFilename          = ""
	proxyWithdrawUnlockedFilename    = ""
	proxyWithdrawRewardsFilename     = ""

	// addresses
	defaultStakingProxyAddress = "0x179b6b1cb6755e31"
)

// ReplaceStakingProxyAddress replaces the import address
// and phase in scripts that use staking proxy contract
func ReplaceStakingProxyAddress(code, proxyAddr string) string {

	code = strings.ReplaceAll(
		code,
		"0x"+defaultStakingProxyAddress,
		"0x"+proxyAddr,
	)

	return code
}

// GenerateSetupNodeAccountScript generates a script that sets up
// a node operator's account to receive staking proxies
func GenerateSetupNodeAccountScript(proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + setupNodeAccountFilename)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}
