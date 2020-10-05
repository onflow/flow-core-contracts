package test

import (
	"testing"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

const (
    dummyLockedTokensAddr = "101010"
	dummyProxyAddr = "010101"
)

// Just make sure we have all the templates under the correct paths.
func TestThatWeHaveAllTheLockedTokensStakerTemplates(t *testing.T) {
    templates.GenerateCreateLockedNodeScript(dummyLockedTokensAddr, dummyProxyAddr)
    templates.GenerateStakeNewLockedTokensScript(dummyLockedTokensAddr, dummyProxyAddr)
    templates.GenerateStakeLockedUnstakedTokensScript(dummyLockedTokensAddr, dummyProxyAddr)
    templates.GenerateStakeLockedRewardedTokensScript(dummyLockedTokensAddr, dummyProxyAddr)
    templates.GenerateUnstakeLockedTokensScript(dummyLockedTokensAddr, dummyProxyAddr)
    templates.GenerateWithdrawLockedUnstakedTokensScript(dummyLockedTokensAddr, dummyProxyAddr)
    templates.GenerateWithdrawLockedRewardedTokensScript(dummyLockedTokensAddr, dummyProxyAddr)
}