package test

import (
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-go-sdk"
	sdk "github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"

	// ft_templates "github.com/onflow/flow-ft/lib/go/templates"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

func TestStakingHelper(t *testing.T) {
	b := newEmulator()
	serviceKey := b.ServiceKey()

	accountKeys := test.AccountKeyGenerator()

	IDTableAccountKey, _ := accountKeys.NewWithSigner()
	IDTableCode := contracts.FlowIDTableStaking(FTAddress, FlowTokenAddress)

	publicKeys := make([]cadence.Value, 1)
	publicKeys[0] = bytesToCadenceArray(IDTableAccountKey.Encode())

	cadencePublicKeys := cadence.NewArray(publicKeys)
	cadenceCode := bytesToCadenceArray(IDTableCode)


	// Deploy FlowIDTable contract
	tx := flow.NewTransaction().
		SetScript(templates.GenerateTransferMinterAndDeployScript(FTAddress, FlowTokenAddress)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys)).
		AddRawArgument(jsoncdc.MustEncode(cadenceCode))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{b.ServiceKey().Address},
		[]crypto.Signer{b.ServiceKey().Signer()},
		false,
	)

	var IDTableAddrRaw sdk.Address

	var i uint64
	i = 0
	for i < 1000 {
		results, _ := b.GetEventsByHeight(i, "flow.AccountCreated")
		for _, event := range results {
			if event.Type == sdk.EventAccountCreated {
				IDTableAddrRaw = sdk.Address(event.Value.Fields[0].(cadence.Address))
			}
		}

		i = i + 1
	}

	IDTableContractAddr := IDTableAddrRaw.String()
	println("IDTable contract was deployed to: " + IDTableContractAddr)

	// Create staking helper admin account
	// stakingHelperAccountKey, stakingHelperSigner := accountKeys.NewWithSigner()
	stakingHelperAccountKey, stakingHelperSigner := accountKeys.NewWithSigner()
	stakingHelperAddress, _ := b.CreateAccount([]*flow.AccountKey{stakingHelperAccountKey}, nil)
	stakingHelperCode := contracts.FlowStakingScaffold(FTAddress, FlowTokenAddress, IDTableContractAddr)
	cadenceStakingHelperCode := bytesToCadenceArray(stakingHelperCode)

	println(stakingHelperAddress.String())

	deployStakingHelperTx := flow.NewTransaction().
		SetScript(templates.GenerateStakingHelperDeployScript(FTAddress, FlowTokenAddress, IDTableContractAddr)).
		SetGasLimit(100).
		SetProposalKey(serviceKey.Address, serviceKey.ID, b.ServiceKey().SequenceNumber).
		SetPayer(serviceKey.Address).
		AddAuthorizer(stakingHelperAddress).
		AddRawArgument(jsoncdc.MustEncode(cadenceStakingHelperCode))

	signAndSubmit(
		t, b, deployStakingHelperTx,
		[]flow.Address{serviceKey.Address, stakingHelperAddress},
		[]crypto.Signer{serviceKey.Signer(), stakingHelperSigner},
		false,
		)

	var StakingHelperAddrRaw sdk.Address

	i = 0
	for i < 1000 {
		results, _ := b.GetEventsByHeight(i, "flow.AccountCreated")
		for _, event := range results {
			if event.Type == sdk.EventAccountCreated {
				StakingHelperAddrRaw = sdk.Address(event.Value.Fields[0].(cadence.Address))
			}
		}
		i = i + 1
	}

	println("StakingHelper contract was deployed to:" + StakingHelperAddrRaw.String())

	/*
	t.Run("Should be able to read empty table fields and initialized fields", func(t *testing.T) {

	})
 	*/
}