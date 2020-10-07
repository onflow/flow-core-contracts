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
    templates.CreateLockedNodeScript(dummyLockedTokensAddr, dummyProxyAddr)
    templates.StakeNewLockedTokensScript(dummyLockedTokensAddr, dummyProxyAddr)
    templates.StakeLockedUnstakedTokensScript(dummyLockedTokensAddr, dummyProxyAddr)
    templates.StakeLockedRewardedTokensScript(dummyLockedTokensAddr, dummyProxyAddr)
    templates.UnstakeLockedTokensScript(dummyLockedTokensAddr, dummyProxyAddr)
    templates.WithdrawLockedUnstakedTokensScript(dummyLockedTokensAddr, dummyProxyAddr)
    templates.WithdrawLockedRewardedTokensScript(dummyLockedTokensAddr, dummyProxyAddr)
}