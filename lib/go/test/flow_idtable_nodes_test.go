package test

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	emulator "github.com/onflow/flow-emulator"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"

	ft_templates "github.com/onflow/flow-ft/lib/go/templates"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

const (
	numberOfNodes      = 1000
	numberOfDelegators = 20000
	nodeMintAmount     = 2000000

	unstakeAllNumNodes      = 1
	unstakeAllNumDelegators = 20000
)

func TestManyNodesIDTable(t *testing.T) {

	t.Parallel()

	b := newBlockchain(emulator.WithTransactionMaxGasLimit(10000000))

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	idTableAddress, _ := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, env, true)

	env.IDTableAddress = idTableAddress.Hex()

	var nodeAccountKey *flow.AccountKey
	var nodeSigner crypto.Signer
	var nodeAddress flow.Address

	// Create a new node account for nodes
	nodeAccountKey, nodeSigner = accountKeys.NewWithSigner()
	nodeAddress, _ = b.CreateAccount([]*flow.AccountKey{nodeAccountKey}, nil)

	approvedNodes := make([]cadence.Value, numberOfNodes)
	nodeRoles := make([]cadence.Value, numberOfNodes)
	nodeNetworkingAddresses := make([]cadence.Value, numberOfNodes)
	nodeNetworkingKeys := make([]cadence.Value, numberOfNodes)
	nodeStakingKeys := make([]cadence.Value, numberOfNodes)
	nodeStakingAmounts := make([]cadence.Value, numberOfNodes)
	nodePaths := make([]cadence.Value, numberOfNodes)

	var delegatorAccountKey *flow.AccountKey
	var delegatorSigner crypto.Signer
	var delegatorAddress flow.Address

	// Create many a new delegator account
	delegatorAccountKey, delegatorSigner = accountKeys.NewWithSigner()
	delegatorAddress, _ = b.CreateAccount([]*flow.AccountKey{delegatorAccountKey}, nil)

	delegatorPaths := make([]cadence.Value, numberOfDelegators)

	t.Run("Should be able to mint tokens for the nodes", func(t *testing.T) {

		totalMint := numberOfNodes * nodeMintAmount
		mintAmount := fmt.Sprintf("%d.0", totalMint)

		script := ft_templates.GenerateMintTokensScript(
			flow.HexToAddress(emulatorFTAddress),
			flow.HexToAddress(emulatorFlowTokenAddress),
			"FlowToken",
		)

		tx := createTxWithTemplateAndAuthorizer(b, script, b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(nodeAddress))
		_ = tx.AddArgument(CadenceUFix64(mintAmount))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address},
			[]crypto.Signer{b.ServiceKey().Signer()},
			false,
		)
	})

	t.Run("Should be able to enable the staking auction", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateStartStakingScript(env)).
			SetGasLimit(9999).
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

	t.Run("Should be able to create many valid Node structs", func(t *testing.T) {

		for i := 0; i < numberOfNodes; i++ {

			id := fmt.Sprintf("%064d", i)

			approvedNodes[i] = CadenceString(id)

			nodeRoles[i] = cadence.NewUInt8(uint8((i % 4) + 1))

			networkingAddress := fmt.Sprintf("%0128d", i)

			nodeNetworkingAddresses[i] = CadenceString(networkingAddress)

			_, stakingKey, _, networkingKey := generateKeysForNodeRegistration(t)

			nodeNetworkingKeys[i] = CadenceString(networkingKey)

			nodeStakingKeys[i] = CadenceString(stakingKey)

			tokenAmount, err := cadence.NewUFix64("1500000.0")
			require.NoError(t, err)

			nodeStakingAmounts[i] = tokenAmount

			nodePaths[i] = cadence.Path{Domain: "storage", Identifier: fmt.Sprintf("node%06d", i)}

		}

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRegisterManyNodesScript(env)).
			SetGasLimit(5000000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(nodeAddress)

		err := tx.AddArgument(cadence.NewArray(approvedNodes))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(nodeRoles))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(nodeNetworkingAddresses))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(nodeNetworkingKeys))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(nodeStakingKeys))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(nodeStakingAmounts))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(nodePaths))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, nodeAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), nodeSigner},
			false,
		)

		result, err := b.ExecuteScript(templates.GenerateReturnTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, result.Succeeded()) {
			t.Log(result.Error.Error())
		}
		proposedIDs := result.Value
		idArray := proposedIDs.(cadence.Array).Values
		assert.Len(t, idArray, numberOfNodes)

	})

	// End staking auction
	t.Run("Should end staking auction, pay rewards, and move tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndStakingScript(env)).
			SetGasLimit(35000).
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
			SetGasLimit(60000).
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

			delegatorPaths[i] = cadence.Path{Domain: "storage", Identifier: fmt.Sprintf("del%06d", i)}

		}

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRegisterManyDelegatorsScript(env)).
			SetGasLimit(2000000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(delegatorAddress)

		err := tx.AddArgument(cadence.NewArray(approvedNodes))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(delegatorPaths))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, delegatorAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), delegatorSigner},
			false,
		)

	})

	// End staking auction
	t.Run("Should end staking auction", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndStakingScript(env)).
			SetGasLimit(200000).
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
	})

	t.Run("Should pay rewards", func(t *testing.T) {
		tx := flow.NewTransaction().
			SetScript(templates.GeneratePayRewardsScript(env)).
			SetGasLimit(300000).
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

	t.Run("Should move tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateMoveTokensScript(env)).
			SetGasLimit(280000).
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

	t.Run("Should end staking auction and move tokens in the same transaction", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndEpochScript(env)).
			SetGasLimit(350000).
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
	})

}

func TestUnstakeAllManyDelegatorsIDTable(t *testing.T) {

	t.Parallel()

	b := newBlockchain(emulator.WithTransactionMaxGasLimit(100000000))

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	idTableAddress, _ := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, env, true)

	env.IDTableAddress = idTableAddress.Hex()

	var nodeAccountKeys [unstakeAllNumNodes]*flow.AccountKey
	var nodeSigners [unstakeAllNumNodes]crypto.Signer
	var nodeAddresses [unstakeAllNumNodes]flow.Address

	// Create many new node accounts for nodes
	for i := 0; i < unstakeAllNumNodes; i++ {
		nodeAccountKeys[i], nodeSigners[i] = accountKeys.NewWithSigner()
		nodeAddresses[i], _ = b.CreateAccount([]*flow.AccountKey{nodeAccountKeys[i]}, nil)
	}

	approvedNodes := make([]cadence.Value, unstakeAllNumNodes)

	var delegatorAccountKey *flow.AccountKey
	var delegatorSigner crypto.Signer
	var delegatorAddress flow.Address

	// Create many new delegator accounts
	delegatorAccountKey, delegatorSigner = accountKeys.NewWithSigner()
	delegatorAddress, _ = b.CreateAccount([]*flow.AccountKey{delegatorAccountKey}, nil)

	delegatorPaths := make([]cadence.Value, unstakeAllNumDelegators)

	t.Run("Should be able to mint tokens for the nodes", func(t *testing.T) {

		for i := 0; i < unstakeAllNumNodes; i++ {

			script := ft_templates.GenerateMintTokensScript(
				flow.HexToAddress(emulatorFTAddress),
				flow.HexToAddress(emulatorFlowTokenAddress),
				"FlowToken",
			)
			tx := createTxWithTemplateAndAuthorizer(b, script, b.ServiceKey().Address)

			_ = tx.AddArgument(cadence.NewAddress(nodeAddresses[i]))
			_ = tx.AddArgument(CadenceUFix64("2000000.0"))

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address},
				[]crypto.Signer{b.ServiceKey().Signer()},
				false,
			)
		}
	})

	t.Run("Should be able to enable the staking auction", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartStakingScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, idTableAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), IDTableSigner},
			false,
		)
	})

	t.Run("Should be able to create many valid Node structs", func(t *testing.T) {

		for i := 0; i < unstakeAllNumNodes; i++ {

			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterNodeScript(env), nodeAddresses[i])

			id := fmt.Sprintf("%064d", i)

			approvedNodes[i] = CadenceString(id)

			role := uint8((i % 4) + 1)

			_, stakingKey, _, networkingKey := generateKeysForNodeRegistration(t)

			err := tx.AddArgument(CadenceString(id))
			require.NoError(t, err)
			err = tx.AddArgument(cadence.NewUInt8(role))
			require.NoError(t, err)
			err = tx.AddArgument(CadenceString(fmt.Sprintf("%0128d", i)))
			require.NoError(t, err)
			err = tx.AddArgument(CadenceString(networkingKey))
			require.NoError(t, err)
			err = tx.AddArgument(CadenceString(stakingKey))
			require.NoError(t, err)
			tokenAmount, err := cadence.NewUFix64("1500000.0")
			require.NoError(t, err)
			err = tx.AddArgument(tokenAmount)
			require.NoError(t, err)

			signAndSubmit(
				t, b, tx,
				[]flow.Address{b.ServiceKey().Address, nodeAddresses[i]},
				[]crypto.Signer{b.ServiceKey().Signer(), nodeSigners[i]},
				false,
			)

		}

	})

	t.Run("Should be able to register many delegators", func(t *testing.T) {

		for i := 0; i < unstakeAllNumDelegators; i++ {

			delegatorPaths[i] = cadence.Path{Domain: "storage", Identifier: fmt.Sprintf("del%06d", i)}

		}

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRegisterManyDelegatorsScript(env)).
			SetGasLimit(2000000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(delegatorAddress)

		err := tx.AddArgument(cadence.NewArray(approvedNodes))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(delegatorPaths))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, delegatorAddress},
			[]crypto.Signer{b.ServiceKey().Signer(), delegatorSigner},
			false,
		)
	})

	t.Run("Should be able request unstake all which also requests to unstake all the delegator's tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeAllScript(env), nodeAddresses[0])

		signAndSubmit(
			t, b, tx,
			[]flow.Address{b.ServiceKey().Address, nodeAddresses[0]},
			[]crypto.Signer{b.ServiceKey().Signer(), nodeSigners[0]},
			false,
		)

	})
}
