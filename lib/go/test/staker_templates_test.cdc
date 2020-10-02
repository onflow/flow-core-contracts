package test

import (
	"testing"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

const (
    dummyLockboxAddr = "101010"
	dummyProxyAddr = "010101"
)

// Just make sure we have all the templates under the correct paths.
func TestThatWeHaveAllTheLockboxStakerTemplates(t *testing.T) {
    templates.GenerateCreateLockedNodeScript(dummyLockboxAddr, dummyProxyAddr)
    templates.GenerateStakeNewLockedTokensScript(dummyLockboxAddr, dummyProxyAddr)
    templates.GenerateStakeLockedUnlockedTokensScript(dummyLockboxAddr, dummyProxyAddr)
    templates.GenerateStakeLockedRewardedTokensScript(dummyLockboxAddr, dummyProxyAddr)
    templates.GenerateUnstakeLockedTokensScript(dummyLockboxAddr, dummyProxyAddr)
    templates.GenerateWithdrawLockedUnlockedTokensScript(dummyLockboxAddr, dummyProxyAddr)
    templates.GenerateWithdrawLockedRewardedTokensScript(dummyLockboxAddr, dummyProxyAddr)
}