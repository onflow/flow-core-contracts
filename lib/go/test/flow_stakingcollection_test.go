package test

import (
	"encoding/hex"
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	emulator "github.com/onflow/flow-emulator"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"

	"github.com/onflow/flow-go-sdk/test"

	"github.com/stretchr/testify/assert"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

func deployCollectionContract(t *testing.T, b *emulator.Blockchain, idTableAddress, stakingProxyAddress, lockedTokensAddress flow.Address, lockedTokensSigner crypto.Signer, env templates.Environment) {

	FlowStakingCollectionCode := contracts.FlowStakingCollection(emulatorFTAddress, emulatorFlowTokenAddress, idTableAddress.String(), stakingProxyAddress.String(), lockedTokensAddress.String())
	FlowStakingCollectionByteCode := cadence.NewString(hex.EncodeToString(FlowStakingCollectionCode))

	// Deploy the QC and DKG contracts
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDeployStakingCollectionScript(), lockedTokensAddress).
		AddRawArgument(jsoncdc.MustEncode(cadence.NewString("FlowStakingCollection"))).
		AddRawArgument(jsoncdc.MustEncode(FlowStakingCollectionByteCode))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address, lockedTokensAddress},
		[]crypto.Signer{b.ServiceKey().Signer(), lockedTokensSigner},
		false,
	)
}

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

	lockedTokensAccountKey, lockedTokensSigner := accountKeys.NewWithSigner()
	lockedTokensAddress := deployLockedTokensContract(t, b, idTableAddress, stakingProxyAddress, lockedTokensAccountKey)
	env.StakingProxyAddress = stakingProxyAddress.Hex()
	env.LockedTokensAddress = lockedTokensAddress.Hex()

	// DEPLOY StakingCollection

	deployCollectionContract(t, b, idTableAddress, stakingProxyAddress, lockedTokensAddress, lockedTokensSigner, env)

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
