package test

import (
	"fmt"
	"strconv"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-emulator"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"

	ft_templates "github.com/onflow/flow-ft/lib/go/templates"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

const (
	firstID = "0000000000000000000000000000000000000000000000000000000000000001"

	firstNetworkingAddress = "netAddress"

	firstStakingKey = "stakingKey"

	firstNetworkingKey = "networkingKey"

	numberOfNodes      = 20
	numberOfDelegators = 10

	unstakeAllNumNodes      = 2
	unstakeAllNumDelegators = 20
)

func TestManyNodesIDTable(t *testing.T) {
	b, err := emulator.NewBlockchain(emulator.WithTransactionMaxGasLimit(1000000))
	if err != nil {
		panic(err)
	}

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	IDTableCode := contracts.FlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress)

	publicKeys := make([]cadence.Value, 1)

	publicKeys[0] = bytesToCadenceArray(IDTableAccountKey.Encode())

	cadencePublicKeys := cadence.NewArray(publicKeys)
	cadenceCode := bytesToCadenceArray(IDTableCode)

	// Deploy the IDTableStaking contract
	tx := flow.NewTransaction().
		SetScript(templates.GenerateTransferMinterAndDeployScript(env)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys)).
		AddRawArgument(jsoncdc.MustEncode(cadence.NewString("FlowIDTableStaking"))).
		AddRawArgument(jsoncdc.MustEncode(cadenceCode))

	_ = tx.AddArgument(CadenceUFix64("1250000.0"))
	_ = tx.AddArgument(CadenceUFix64("0.08"))

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

	var userAccountKeys [numberOfNodes]*flow.AccountKey
	var userSigners [numberOfNodes]crypto.Signer
	var userAddresses [numberOfNodes]flow.Address

	// Create many new user accounts for nodes
	for i := 0; i < numberOfNodes; i++ {
		userAccountKeys[i], userSigners[i] = accountKeys.NewWithSigner()
		userAddresses[i], _ = b.CreateAccount([]*flow.AccountKey{userAccountKeys[i]}, nil)
	}

	approvedNodes := make([]cadence.Value, numberOfNodes)

	var delegatorAccountKeys [numberOfDelegators]*flow.AccountKey
	var delegatorSigners [numberOfDelegators]crypto.Signer
	var delegatorAddresses [numberOfDelegators]flow.Address

	// Create many new delegator accounts
	for i := 0; i < numberOfDelegators; i++ {
		delegatorAccountKeys[i], delegatorSigners[i] = accountKeys.NewWithSigner()
		delegatorAddresses[i], _ = b.CreateAccount([]*flow.AccountKey{delegatorAccountKeys[i]}, nil)
	}

	t.Run("Should be able to mint tokens for the nodes", func(t *testing.T) {

		for i := 0; i < numberOfNodes; i++ {

			tx := flow.NewTransaction().
				SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
				SetGasLimit(9999).
				SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
				SetPayer(b.ServiceKey().Address).
				AddAuthorizer(b.ServiceKey().Address)

			_ = tx.AddArgument(cadence.NewAddress(userAddresses[i]))
			_ = tx.AddArgument(CadenceUFix64("2000000.0"))

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address},
				[]crypto.Signer{b.ServiceKey().Signer()},
				false,
			)
		}
	})

	t.Run("Should be able to mint tokens for the delegators", func(t *testing.T) {

		for i := 0; i < numberOfDelegators; i++ {

			tx := flow.NewTransaction().
				SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
				SetGasLimit(9999).
				SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
				SetPayer(b.ServiceKey().Address).
				AddAuthorizer(b.ServiceKey().Address)

			_ = tx.AddArgument(cadence.NewAddress(delegatorAddresses[i]))
			_ = tx.AddArgument(CadenceUFix64("2000000.0"))

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address},
				[]crypto.Signer{b.ServiceKey().Signer()},
				false,
			)
		}
	})

	t.Run("Should be able to create many valid Node structs", func(t *testing.T) {

		for i := 0; i < numberOfNodes; i++ {

			tx := flow.NewTransaction().
				SetScript(templates.GenerateRegisterNodeScript(env)).
				SetGasLimit(4000).
				SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
				SetPayer(b.ServiceKey().Address).
				AddAuthorizer(userAddresses[i])

			id := fmt.Sprintf("%064d", i)

			approvedNodes[i] = cadence.NewString(id)

			role := uint8((i % 4) + 1)

			err := tx.AddArgument(cadence.NewString(id))
			require.NoError(t, err)
			err = tx.AddArgument(cadence.NewUInt8(role))
			require.NoError(t, err)
			err = tx.AddArgument(cadence.NewString(firstNetworkingAddress + strconv.Itoa(i)))
			require.NoError(t, err)
			err = tx.AddArgument(cadence.NewString(firstNetworkingKey + strconv.Itoa(i)))
			require.NoError(t, err)
			err = tx.AddArgument(cadence.NewString(firstStakingKey + strconv.Itoa(i)))
			require.NoError(t, err)
			tokenAmount, err := cadence.NewUFix64("1500000.0")
			require.NoError(t, err)
			err = tx.AddArgument(tokenAmount)
			require.NoError(t, err)

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address, userAddresses[i]},
				[]crypto.Signer{b.ServiceKey().Signer(), userSigners[i]},
				false,
			)

		}

		result, err := b.ExecuteScript(templates.GenerateReturnTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray := proposedIDs.(cadence.Array).Values
		assert.Equal(t, numberOfNodes, len(idArray))

		result, err = b.ExecuteScript(templates.GenerateReturnProposedTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs = result.Value
		idArray = proposedIDs.(cadence.Array).Values
		assert.Equal(t, numberOfNodes, len(idArray))

	})

	t.Run("Should be able to commit additional tokens for a node", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateStakeNewTokensScript(env)).
			SetGasLimit(100).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(userAddresses[numberOfNodes-1])

		tokenAmount, err := cadence.NewUFix64("100000.0")
		require.NoError(t, err)
		err = tx.AddArgument(tokenAmount)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, userAddresses[numberOfNodes-1]},
			[]crypto.Signer{b.ServiceKey().Signer(), userSigners[numberOfNodes-1]},
			false,
		)
	})

	// End staking auction
	t.Run("Should end staking auction, pay rewards, and move tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndStakingScript(env)).
			SetGasLimit(16000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		err := tx.AddArgument(cadence.NewArray(approvedNodes))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GeneratePayRewardsScript(env)).
			SetGasLimit(16000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateMoveTokensScript(env)).
			SetGasLimit(20000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

	})

	t.Run("Should be able to register many delegators", func(t *testing.T) {

		for i := 0; i < numberOfDelegators; i++ {

			tx := flow.NewTransaction().
				SetScript(templates.GenerateRegisterDelegatorScript(env)).
				SetGasLimit(100).
				SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
				SetPayer(b.ServiceKey().Address).
				AddAuthorizer(delegatorAddresses[i])

			nodeID := i % numberOfNodes

			err := tx.AddArgument(approvedNodes[nodeID])
			require.NoError(t, err)

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address, delegatorAddresses[i]},
				[]crypto.Signer{b.ServiceKey().Signer(), delegatorSigners[i]},
				false,
			)

		}
	})

	// End staking auction
	t.Run("Should end staking auction, pay rewards, and move tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndStakingScript(env)).
			SetGasLimit(30000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		err := tx.AddArgument(cadence.NewArray(approvedNodes))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GeneratePayRewardsScript(env)).
			SetGasLimit(30000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

		tx = flow.NewTransaction().
			SetScript(templates.GenerateMoveTokensScript(env)).
			SetGasLimit(30000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)

	})

}

func TestUnstakeAllManyDelegatorsIDTable(t *testing.T) {
	b, err := emulator.NewBlockchain(emulator.WithTransactionMaxGasLimit(1000000))
	if err != nil {
		panic(err)
	}

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, _ := accountKeys.NewWithSigner()
	IDTableCode := contracts.FlowIDTableStaking(emulatorFTAddress, emulatorFlowTokenAddress)

	publicKeys := make([]cadence.Value, 1)

	publicKeys[0] = bytesToCadenceArray(IDTableAccountKey.Encode())

	cadencePublicKeys := cadence.NewArray(publicKeys)
	cadenceCode := bytesToCadenceArray(IDTableCode)

	// Deploy the IDTableStaking contract
	tx := flow.NewTransaction().
		SetScript(templates.GenerateTransferMinterAndDeployScript(env)).
		SetGasLimit(100).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(b.ServiceKey().Address).
		AddRawArgument(jsoncdc.MustEncode(cadencePublicKeys)).
		AddRawArgument(jsoncdc.MustEncode(cadence.NewString("FlowIDTableStaking"))).
		AddRawArgument(jsoncdc.MustEncode(cadenceCode))

	_ = tx.AddArgument(CadenceUFix64("1250000.0"))
	_ = tx.AddArgument(CadenceUFix64("0.08"))

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

	var userAccountKeys [unstakeAllNumNodes]*flow.AccountKey
	var userSigners [unstakeAllNumNodes]crypto.Signer
	var userAddresses [unstakeAllNumNodes]flow.Address

	// Create many new user accounts for nodes
	for i := 0; i < unstakeAllNumNodes; i++ {
		userAccountKeys[i], userSigners[i] = accountKeys.NewWithSigner()
		userAddresses[i], _ = b.CreateAccount([]*flow.AccountKey{userAccountKeys[i]}, nil)
	}

	approvedNodes := make([]cadence.Value, unstakeAllNumNodes)

	var delegatorAccountKeys [unstakeAllNumDelegators]*flow.AccountKey
	var delegatorSigners [unstakeAllNumDelegators]crypto.Signer
	var delegatorAddresses [unstakeAllNumDelegators]flow.Address

	// Create many new delegator accounts
	for i := 0; i < unstakeAllNumDelegators; i++ {
		delegatorAccountKeys[i], delegatorSigners[i] = accountKeys.NewWithSigner()
		delegatorAddresses[i], _ = b.CreateAccount([]*flow.AccountKey{delegatorAccountKeys[i]}, nil)
	}

	t.Run("Should be able to mint tokens for the nodes", func(t *testing.T) {

		for i := 0; i < unstakeAllNumNodes; i++ {

			tx := flow.NewTransaction().
				SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
				SetGasLimit(9999).
				SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
				SetPayer(b.ServiceKey().Address).
				AddAuthorizer(b.ServiceKey().Address)

			_ = tx.AddArgument(cadence.NewAddress(userAddresses[i]))
			_ = tx.AddArgument(CadenceUFix64("2000000.0"))

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address},
				[]crypto.Signer{b.ServiceKey().Signer()},
				false,
			)
		}
	})

	t.Run("Should be able to mint tokens for the delegators", func(t *testing.T) {

		for i := 0; i < unstakeAllNumDelegators; i++ {

			tx := flow.NewTransaction().
				SetScript(ft_templates.GenerateMintTokensScript(flow.HexToAddress(emulatorFTAddress), flow.HexToAddress(emulatorFlowTokenAddress), "FlowToken")).
				SetGasLimit(9999).
				SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
				SetPayer(b.ServiceKey().Address).
				AddAuthorizer(b.ServiceKey().Address)

			_ = tx.AddArgument(cadence.NewAddress(delegatorAddresses[i]))
			_ = tx.AddArgument(CadenceUFix64("2000000.0"))

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address},
				[]crypto.Signer{b.ServiceKey().Signer()},
				false,
			)
		}
	})

	t.Run("Should be able to create many valid Node structs", func(t *testing.T) {

		for i := 0; i < unstakeAllNumNodes; i++ {

			tx := flow.NewTransaction().
				SetScript(templates.GenerateRegisterNodeScript(env)).
				SetGasLimit(4000).
				SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
				SetPayer(b.ServiceKey().Address).
				AddAuthorizer(userAddresses[i])

			id := fmt.Sprintf("%064d", i)

			approvedNodes[i] = cadence.NewString(id)

			role := uint8((i % 4) + 1)

			err := tx.AddArgument(cadence.NewString(id))
			require.NoError(t, err)
			err = tx.AddArgument(cadence.NewUInt8(role))
			require.NoError(t, err)
			err = tx.AddArgument(cadence.NewString(firstNetworkingAddress + strconv.Itoa(i)))
			require.NoError(t, err)
			err = tx.AddArgument(cadence.NewString(firstNetworkingKey + strconv.Itoa(i)))
			require.NoError(t, err)
			err = tx.AddArgument(cadence.NewString(firstStakingKey + strconv.Itoa(i)))
			require.NoError(t, err)
			tokenAmount, err := cadence.NewUFix64("1500000.0")
			require.NoError(t, err)
			err = tx.AddArgument(tokenAmount)
			require.NoError(t, err)

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address, userAddresses[i]},
				[]crypto.Signer{b.ServiceKey().Signer(), userSigners[i]},
				false,
			)

		}

	})

	t.Run("Should be able to register many delegators", func(t *testing.T) {

		for i := 0; i < unstakeAllNumDelegators; i++ {

			tx := flow.NewTransaction().
				SetScript(templates.GenerateRegisterDelegatorScript(env)).
				SetGasLimit(100).
				SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
				SetPayer(b.ServiceKey().Address).
				AddAuthorizer(delegatorAddresses[i])

			nodeID := 0

			err := tx.AddArgument(approvedNodes[nodeID])
			require.NoError(t, err)

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address, delegatorAddresses[i]},
				[]crypto.Signer{b.ServiceKey().Signer(), delegatorSigners[i]},
				false,
			)

		}
	})

	t.Run("Should be able request unstake all which also requests to unstake all the delegator's tokens", func(t *testing.T) {

		tx = flow.NewTransaction().
			SetScript(templates.GenerateUnstakeAllScript(env)).
			SetGasLimit(10000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(userAddresses[0])

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, userAddresses[0]},
			[]crypto.Signer{b.ServiceKey().Signer(), userSigners[0]},
			false,
		)

	})
}
