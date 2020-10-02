package templates

import (
	"strings"

	"github.com/onflow/flow-core-contracts/lib/go/templates/internal/assets"
)

const (
	// admin templates
	createAdminCollectionFilename = "lockbox/admin/create_admin_collection.cdc"
	createLockedAccountsFilename  = "lockbox/admin/create_shared_account.cdc"

	// staker templates
	createLockedNodeFilename             = "lockbox/staker/register_node.cdc"
	stakeNewLockedTokensFilename         = "lockbox/staker/stake_new_tokens.cdc"
	stakeLockedUnlockedTokensFilename    = "lockbox/staker/stake_unlocked_tokens.cdc"
	stakeLockedRewardedTokensFilename    = "lockbox/staker/stake_rewarded_tokens.cdc"
	unstakeLockedTokensFilename          = "lockbox/staker/request_unstake.cdc"
	withdrawLockedUnlockedTokensFilename = "lockbox/staker/withdraw_unlocked_tokens.cdc"
	withdrawLockedRewardedTokensFilename = "lockbox/staker/withdraw_rewarded_tokens.cdc"

	// delegator templates
	registerLockedDelegatorFilename               = "lockbox/delegator/register_delegator.cdc"
	delegateNewLockedTokensFilename               = "lockbox/delegator/delegate_new_locked_tokens.cdc"
	delegateLockedUnlockedTokensFilename          = "lockbox/delegator/delegate_locked_unlocked_tokens.cdc"
	delegateLockedRewardedTokensFilename          = "lockbox/delegator/delegate_locked_rewarded_tokens.cdc"
	requestUnstakingLockedDelegatedTokensFilename = "lockbox/delegator/request_unstaking_locked_delegated_tokens.cdc"
	withdrawLockedUnlockedDelegatedTokensFilename = "lockbox/delegator/withdraw_locked_unlocked_delegated_tokens.cdc"
	withdrawLockedRewardedDelegatedTokensFilename = "lockbox/delegator/withdraw_locked_rewarded_delegated_tokens.cdc"

	// staking helper templates
	registerNodeFilename = "stakingProxy/stakingHelper/sh_register_node.cdc"

	// addresses
	defaultLockboxAddress = "0xf3fcd2c1a78f5eee"
)

// ReplaceLockboxAddress replaces the import address
// and phase in scripts that return info about a specific node and phase
func ReplaceLockboxAddress(code, lockboxAddress string) string {

	code = strings.ReplaceAll(
		code,
		"0x"+defaultLockboxAddress,
		"0x"+lockboxAddress,
	)

	return code
}

// GenerateCreateLockedNodeScript creates a script that creates a new
// node request with locked tokens
func GenerateCreateLockedNodeScript(lockboxAddr, proxyAddr string) []byte {
	code := assets.MustAssetString(filePath + createLockedNodeFilename)

	code = ReplaceLockboxAddress(code, lockboxAddr)

	return []byte(ReplaceStakingProxyAddress(code, proxyAddr))
}
