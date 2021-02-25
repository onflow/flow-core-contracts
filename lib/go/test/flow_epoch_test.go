package test

import (
	"testing"

	"github.com/onflow/cadence"

	"github.com/onflow/flow-go-sdk/test"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

func TestEpochDeployment(t *testing.T) {
	t.Parallel()
	b := newBlockchain()
	accountKeys := test.AccountKeyGenerator()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	// idTableAddress := initializeAllEpochContracts(t, b, IDTableAccountKey, IDTableSigner, &env)
	_ = initializeAllEpochContracts(t, b, IDTableAccountKey, IDTableSigner, &env, 0, 70, 50, 2, 4, "lolsoRandom")

	result := executeScriptAndCheck(t, b, templates.GenerateGetCurrentEpochCounterScript(env), nil)
	assertEqual(t, cadence.NewUInt64(0), result)

	result = executeScriptAndCheck(t, b, templates.GenerateGetProposedEpochCounterScript(env), nil)
	assertEqual(t, cadence.NewUInt64(1), result)

	verifyEpochMetadata(t, b, env,
		EpochMetadata{
			counter:           0,
			seed:              "lolsoRandom",
			startView:         0,
			endView:           69,
			stakingEndView:    49,
			collectorClusters: nil,
			clusterQCs:        nil,
			dkgKeys:           nil})
}
