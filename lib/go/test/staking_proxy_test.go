package test

import (
	"testing"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

const (
	dummyProxyAddr = "010101"
)

func TestThatWeHaveAllTheTemplates(t *testing.T) {
	templates.GenerateSetupNodeAccountScript(dummyProxyAddr)
	templates.GenerateAddNodeInfoScript(dummyProxyAddr)
	templates.GenerateRemoveNodeInfoScript(dummyProxyAddr)
	templates.GenerateRemoveStakingProxyScript(dummyProxyAddr)
	templates.GenerateProxyStakeNewTokensScript(dummyProxyAddr)
	templates.GenerateProxyStakeUnlockedTokensScript(dummyProxyAddr)
	templates.GenerateProxyRequestUnstakingScript(dummyProxyAddr)
	templates.GenerateProxyUnstakeAllScript(dummyProxyAddr)
	templates.GenerateProxyWithdrawUnlockedScript(dummyProxyAddr)
	templates.GenerateProxyWithdrawRewardsScript(dummyProxyAddr)
}
