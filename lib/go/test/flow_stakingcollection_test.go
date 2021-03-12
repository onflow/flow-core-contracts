package test

import (
	"testing"

	sdktemplates "github.com/onflow/flow-go-sdk/templates"

	"github.com/onflow/flow-go-sdk/test"

	"github.com/stretchr/testify/assert"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

func TestStakingCollection(t *testing.T) {

	t.Parallel()

	b := newBlockchain()

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	accountKeys := test.AccountKeyGenerator()

	// DEPLOY IDTableStaking

	// Create new keys for the ID table account
	IDTableAccountKey, _ := accountKeys.NewWithSigner()
	var idTableAddress = deployStakingContract(t, b, IDTableAccountKey, env)

	env.IDTableAddress = idTableAddress.Hex()

	// DEPLOY StakingProxy

	// Deploy the StakingProxy contract
	stakingProxyCode := contracts.FlowStakingProxy()
	stakingProxyAddress, err := b.CreateAccount(nil, []sdktemplates.Contract{
		{
			Name:   "StakingProxy",
			Source: string(stakingProxyCode),
		},
	})
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}
	_, err = b.CommitBlock()
	assert.NoError(t, err)

	//adminAccountKey := accountKeys.New()
	lockedTokensAddress := deployLockedTokensContract(t, b, idTableAddress, stakingProxyAddress)
	env.StakingProxyAddress = stakingProxyAddress.Hex()
	env.LockedTokensAddress = lockedTokensAddress.Hex()

	// DEPLOY StakingCollection

	//FlowStakingCollectionKey, _ := accountKeys.NewWithSigner()
	FlowStakingCollectionCode := contracts.FlowStakingCollection(emulatorFTAddress, emulatorFlowTokenAddress, idTableAddress.String(), stakingProxyAddress.String(), lockedTokensAddress.String())

	//stakingCollectionAddress, err := b.CreateAccount(nil, []sdktemplates.Contract{
	_, err = b.CreateAccount(nil, []sdktemplates.Contract{
		{
			Name:   "StakingCollection",
			Source: string(FlowStakingCollectionCode),
		},
	})
	if !assert.NoError(t, err) {
		t.Log(err.Error())
	}
	_, err = b.CommitBlock()
	assert.NoError(t, err)

	t.Run("Should be able to set up the admin account", func(t *testing.T) {

		// tx = createTxWithTemplateAndAuthorizer(b, ft_templates.GenerateMintTokensScript(
		// 	flow.HexToAddress(emulatorFTAddress),
		// 	flow.HexToAddress(emulatorFlowTokenAddress),
		// 	"FlowToken",
		// ), b.ServiceKey().Address)

		// _ = tx.AddArgument(cadence.NewAddress(lockedTokensAddress))
		// _ = tx.AddArgument(CadenceUFix64("1000000000.0"))

		// signAndSubmit(
		// 	t, b, tx,
		// 	[]flow.Address{b.ServiceKey().Address},
		// 	[]crypto.Signer{b.ServiceKey().Signer()},
		// 	false,
		// )
	})

}
