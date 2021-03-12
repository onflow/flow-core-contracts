package test

import (
	"encoding/hex"
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	
	"github.com/onflow/flow-go-sdk/test"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

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
	IDTableCode := contracts.TESTFlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress)

	publicKeys := make([]cadence.Value, 1)

	publicKeys[0] = bytesToCadenceArray(IDTableAccountKey.Encode())

	IDTableStakingCadencePublicKeys := cadence.NewArray(publicKeys)
	IDTableStakingCadenceCode := bytesToCadenceArray(IDTableCode)

	// Deploy the IDTableStaking contract
	tx := flow.NewTransaction().
		SetScript(templates.GenerateTransferMinterAndDeployScript(env)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(IDTableStakingCadencePublicKeys)).
		AddRawArgument(jsoncdc.MustEncode(cadence.NewString("FlowIDTableStaking"))).
		AddRawArgument(jsoncdc.MustEncode(IDTableStakingCadenceCode))

	_ = tx.AddArgument(CadenceUFix64("1250000.0"))
	_ = tx.AddArgument(CadenceUFix64("0.03"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{b.ServiceKey().Signer()},
		false,
	)

	var idTableAddress flow.Address

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := b.GetEventsByHeight(i, "flow.AccountCreated")

		for _, event := range results {
			if event.Type == flow.EventAccountCreated {
				idTableAddress = flow.Address(event.Value.Fields[0].(cadence.Address))
			}
		}

		i = i + 1
	}

	env.IDTableAddress = idTableAddress.Hex()

	// DEPLOY StakingProxy

	var stakingProxyAddress flow.Address

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

	env.StakingProxyAddress = stakingProxyAddress.Hex()

	adminAccountKey := accountKeys.New()

	lockedTokensAddress := deployLockedTokensContract(t, b, idTableAddress, stakingProxyAddress)

	env.LockedTokensAddress = lockedTokensAddress.Hex()

	// DEPLOY LockedTokens

	lockedTokensCode := contracts.FlowLockedTokens(
		emulatorFTAddress,
		emulatorFlowTokenAddress,
		idTableAddress.Hex(),
		stakingProxyAddress.Hex(),
	)

	lockedTokensCadenceCode := cadence.NewString(hex.EncodeToString(lockedTokensCode))

	createLockedTokensContractTx := createTxWithTemplateAndAuthorizer(b, templates.GenerateDeployLockedTokens(), b.ServiceKey().Address)

	createLockedTokensContractTx.AddRawArgument(jsoncdc.MustEncode(cadence.NewString("LockedTokens")))
	createLockedTokensContractTx.AddRawArgument(jsoncdc.MustEncode(lockedTokensCadenceCode))
	createLockedTokensContractTx.AddRawArgument(jsoncdc.MustEncode(cadence.NewArray(nil)))

	createLockedTokensContractTxErr := createLockedTokensContractTx.SignEnvelope(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().Signer())
	require.NoError(t, createLockedTokensContractTxErr)

	createLockedTokensContractTxErr = b.AddTransaction(*createLockedTokensContractTx)
	require.NoError(t, createLockedTokensContractTxErr)

	result, err := b.ExecuteNextTransaction()
	require.NoError(t, err)
	require.NoError(t, result.Error)

	var lockedTokensAddr flow.Address

	for _, event := range result.Events {
		if event.Type == flow.EventAccountCreated {
			accountCreatedEvent := flow.AccountCreatedEvent(event)
			lockedTokensAddr = accountCreatedEvent.Address()
			break
		}
	}

	_, err = b.CommitBlock()
	require.NoError(t, err)

	// DEPLOY StakingCollection

	FlowStakingCollectionKey, _ := accountKeys.NewWithSigner()
	FlowStakingCollectionCode := contracts.FlowStakingCollection(emulatorFTAddress, emulatorFlowTokenAddress, idTableAddress.String(), stakingProxyAddress.String(), lockedTokensAddr.String())

	stakingCollectionPublicKeys := make([]cadence.Value, 1)

	publicKeys[0] = bytesToCadenceArray(FlowStakingCollectionKey.Encode())

	cadencePublicKeys := cadence.NewArray(stakingCollectionPublicKeys)
	cadenceCode := bytesToCadenceArray(FlowStakingCollectionCode)

	createStakingCollectionContractTx := flow.NewTransaction().
		SetScript(templates.GenerateTransferMinterAndDeployScript(env)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys)).
		AddRawArgument(jsoncdc.MustEncode(cadence.NewString("StakingCollection"))).
		AddRawArgument(jsoncdc.MustEncode(cadenceCode))

	// _ = tx.AddArgument(CadenceUFix64("1250000.0"))
	// _ = tx.AddArgument(CadenceUFix64("0.03"))

	signAndSubmit(
		t, b, createStakingCollectionContractTx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{b.ServiceKey().Signer()},
		false,
	)

	// var idTableAddress flow.Address

	// var i uint64
	// i = 0
	// for i < 1000 {
	// 	results, _ := b.GetEventsByHeight(i, "flow.AccountCreated")

	// 	for _, event := range results {
	// 		if event.Type == flow.EventAccountCreated {
	// 			idTableAddress = flow.Address(event.Value.Fields[0].(cadence.Address))
	// 		}
	// 	}

	// 	i = i + 1
	// }

	// env.IDTableAddress = idTableAddress.Hex()

	// // Deploy the StakingProxy contract
	// stakingProxyCode := contracts.FlowStakingProxy()
	// stakingProxyAddress, err := b.CreateAccount(nil, []sdktemplates.Contract{
	// 	{
	// 		Name:   "StakingProxy",
	// 		Source: string(stakingProxyCode),
	// 	},
	// })
	// if !assert.NoError(t, err) {
	// 	t.Log(err.Error())
	// }

	// _, err = b.CommitBlock()
	// assert.NoError(t, err)

	// env.StakingProxyAddress = stakingProxyAddress.Hex()

	// adminAccountKey := accountKeys.New()

	// lockedTokensAddress := deployLockedTokensContract(t, b, idTableAddress, stakingProxyAddress)

	// env.LockedTokensAddress = lockedTokensAddress.Hex()

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
