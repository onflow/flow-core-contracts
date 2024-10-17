package test

import (
	"context"
	"fmt"
	"testing"

	"github.com/onflow/cadence/runtime/common"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/cadence"
	"github.com/onflow/flow-emulator/emulator"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/onflow/flow-go-sdk/test"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

const (
	numberOfNodes      = 100
	numberOfDelegators = 2000
	nodeMintAmount     = 2000000

	unstakeAllNumNodes      = 1
	unstakeAllNumDelegators = 2000
)

func TestIDTableManyNodes(t *testing.T) {

	t.Parallel()

	b, adapter := newBlockchain(emulator.WithTransactionMaxGasLimit(10000000))

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
		BurnerAddress:        emulatorServiceAccount,
		StorageFeesAddress:   emulatorServiceAccount,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	idTableAddress, _ := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, &env, true, []uint64{10000, 10000, 10000, 10000, 10000})

	env.IDTableAddress = idTableAddress.Hex()

	// Change the delegator staking minimum to zero
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateChangeDelegatorMinimumsScript(env), idTableAddress)

	tx.AddArgument(CadenceUFix64("0.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	var nodeAccountKey *flow.AccountKey
	var nodeSigner crypto.Signer
	var nodeAddress flow.Address

	// Create a new node account for nodes
	nodeAccountKey, nodeSigner = accountKeys.NewWithSigner()
	nodeAddress, _ = adapter.CreateAccount(context.Background(), []*flow.AccountKey{nodeAccountKey}, nil)

	approvedNodes := make([]cadence.Value, numberOfNodes)
	approvedNodesStringArray := make([]string, numberOfNodes)
	nodeRoles := make([]cadence.Value, numberOfNodes)
	nodeNetworkingAddresses := make([]cadence.Value, numberOfNodes)
	nodeNetworkingKeys := make([]cadence.Value, numberOfNodes)
	nodeStakingKeys := make([]cadence.Value, numberOfNodes)
	nodeStakingKeyPOPs := make([]cadence.Value, numberOfNodes)
	nodeStakingAmounts := make([]cadence.Value, numberOfNodes)
	nodePaths := make([]cadence.Value, numberOfNodes)

	var delegatorAccountKey *flow.AccountKey
	var delegatorSigner crypto.Signer
	var delegatorAddress flow.Address

	// Create many a new delegator account
	delegatorAccountKey, delegatorSigner = accountKeys.NewWithSigner()
	delegatorAddress, _ = adapter.CreateAccount(context.Background(), []*flow.AccountKey{delegatorAccountKey}, nil)

	delegatorPaths := make([]cadence.Value, numberOfDelegators)

	t.Run("Should be able to mint tokens for the nodes", func(t *testing.T) {

		totalMint := numberOfNodes * nodeMintAmount
		mintAmount := fmt.Sprintf("%d.0", totalMint)

		script := templates.GenerateMintFlowScript(env)

		tx := createTxWithTemplateAndAuthorizer(b, script, b.ServiceKey().Address)

		_ = tx.AddArgument(cadence.NewAddress(nodeAddress))
		_ = tx.AddArgument(CadenceUFix64(mintAmount))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{},
			[]crypto.Signer{},
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
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)
	})

	t.Run("Should be able to create many valid Node structs", func(t *testing.T) {

		for i := 0; i < numberOfNodes; i++ {

			id := fmt.Sprintf("%064d", i)

			approvedNodes[i] = CadenceString(id)
			approvedNodesStringArray[i] = id

			nodeRoles[i] = cadence.NewUInt8(uint8((i % 4) + 1))

			networkingAddress := fmt.Sprintf("%0128d", i)

			nodeNetworkingAddresses[i] = CadenceString(networkingAddress)

			_, stakingKey, stakingPOP, _, networkingKey := generateKeysForNodeRegistration(t)

			nodeNetworkingKeys[i] = CadenceString(networkingKey)

			nodeStakingKeys[i] = CadenceString(stakingKey)

			nodeStakingKeyPOPs[i] = CadenceString(stakingPOP)

			tokenAmount, err := cadence.NewUFix64("1500000.0")
			require.NoError(t, err)

			nodeStakingAmounts[i] = tokenAmount

			nodePaths[i] = cadence.Path{Domain: common.PathDomainStorage, Identifier: fmt.Sprintf("node%06d", i)}

		}

		assertCandidateLimitsEquals(t, b, env, []uint64{10000, 10000, 10000, 10000, 10000})

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

		err = tx.AddArgument(cadence.NewArray(nodeStakingKeyPOPs))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(nodeStakingAmounts))
		require.NoError(t, err)

		err = tx.AddArgument(cadence.NewArray(nodePaths))
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{nodeAddress},
			[]crypto.Signer{nodeSigner},
			false,
		)

		scriptResult, err := b.ExecuteScript(templates.GenerateReturnTableScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, scriptResult.Succeeded()) {
			t.Log(scriptResult.Error.Error())
		}
		proposedIDs := scriptResult.Value
		idArray := proposedIDs.(cadence.Array).Values
		assert.Len(t, idArray, numberOfNodes)

	})

	approvedNodesDict := generateCadenceNodeDictionary(approvedNodesStringArray)

	// End staking auction
	t.Run("Should end staking auction, pay rewards, and move tokens", func(t *testing.T) {

		tx := flow.NewTransaction().
			SetScript(templates.GenerateEndStakingScript(env)).
			SetGasLimit(35000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(idTableAddress)

		err := tx.AddArgument(approvedNodesDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
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
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
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
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)

	})

	t.Run("Should be able to register many delegators", func(t *testing.T) {

		for i := 0; i < numberOfDelegators; i++ {

			delegatorPaths[i] = cadence.Path{Domain: common.PathDomainStorage, Identifier: fmt.Sprintf("del%06d", i)}

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
			[]flow.Address{delegatorAddress},
			[]crypto.Signer{delegatorSigner},
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

		err := tx.AddArgument(approvedNodesDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
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
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
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
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
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

		err := tx.AddArgument(approvedNodesDict)
		require.NoError(t, err)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)
	})

}

func TestIDTableOutOfBoundsAccess(t *testing.T) {

	t.Parallel()

	b, adapter := newBlockchain(emulator.WithTransactionMaxGasLimit(10000000))

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
		BurnerAddress:        emulatorServiceAccount,
		StorageFeesAddress:   emulatorServiceAccount,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	idTableAddress, _ := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, &env, true, []uint64{10000, 10000, 10000, 10000, 10000})

	env.IDTableAddress = idTableAddress.Hex()

	var nodeAccountKey *flow.AccountKey
	var nodeSigner crypto.Signer
	var nodeAddress flow.Address

	// Create a new node account for nodes
	nodeAccountKey, nodeSigner = accountKeys.NewWithSigner()
	nodeAddress, _ = adapter.CreateAccount(context.Background(), []*flow.AccountKey{nodeAccountKey}, nil)

	approvedNodes := make([]cadence.Value, numberOfNodes)
	approvedNodesStringArray := make([]string, numberOfNodes)
	nodeRoles := make([]cadence.Value, numberOfNodes)
	nodeNetworkingAddresses := make([]cadence.Value, numberOfNodes)
	nodeNetworkingKeys := make([]cadence.Value, numberOfNodes)
	nodeStakingKeys := make([]cadence.Value, numberOfNodes)
	nodeStakingKeyPOPs := make([]cadence.Value, numberOfNodes)
	nodeStakingAmounts := make([]cadence.Value, numberOfNodes)
	nodePaths := make([]cadence.Value, numberOfNodes)

	totalMint := numberOfNodes * nodeMintAmount
	mintAmount := fmt.Sprintf("%d.0", totalMint)

	script := templates.GenerateMintFlowScript(env)
	tx := createTxWithTemplateAndAuthorizer(b, script, b.ServiceKey().Address)
	_ = tx.AddArgument(cadence.NewAddress(nodeAddress))
	_ = tx.AddArgument(CadenceUFix64(mintAmount))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{},
		[]crypto.Signer{},
		false,
	)

	tx = flow.NewTransaction().
		SetScript(templates.GenerateStartStakingScript(env)).
		SetGasLimit(9999).
		SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
		SetPayer(b.ServiceKey().Address).
		AddAuthorizer(idTableAddress)

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	t.Run("Should be able to create many valid Node structs", func(t *testing.T) {

		for i := 0; i < numberOfNodes; i++ {

			id := fmt.Sprintf("%064d", i)

			approvedNodes[i] = CadenceString(id)
			approvedNodesStringArray[i] = id

			nodeRoles[i] = cadence.NewUInt8(uint8((i % 4) + 1))

			networkingAddress := fmt.Sprintf("%0128d", i)

			nodeNetworkingAddresses[i] = CadenceString(networkingAddress)

			_, stakingKey, stakingKeyPOP, _, networkingKey := generateKeysForNodeRegistration(t)

			nodeNetworkingKeys[i] = CadenceString(networkingKey)

			nodeStakingKeys[i] = CadenceString(stakingKey)

			nodeStakingKeyPOPs[i] = CadenceString(stakingKeyPOP)

			tokenAmount, err := cadence.NewUFix64("1500000.0")
			require.NoError(t, err)

			nodeStakingAmounts[i] = tokenAmount
			nodePaths[i] = cadence.Path{Domain: common.PathDomainStorage, Identifier: fmt.Sprintf("node%06d", i)}

		}

		assertCandidateLimitsEquals(t, b, env, []uint64{10000, 10000, 10000, 10000, 10000})

		tx := flow.NewTransaction().
			SetScript(templates.GenerateRegisterManyNodesScript(env)).
			SetGasLimit(5000000).
			SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
			SetPayer(b.ServiceKey().Address).
			AddAuthorizer(nodeAddress)

		tx.AddArgument(cadence.NewArray(approvedNodes))
		tx.AddArgument(cadence.NewArray(nodeRoles))
		tx.AddArgument(cadence.NewArray(nodeNetworkingAddresses))
		tx.AddArgument(cadence.NewArray(nodeNetworkingKeys))
		tx.AddArgument(cadence.NewArray(nodeStakingKeys))
		tx.AddArgument(cadence.NewArray(nodeStakingKeyPOPs))
		tx.AddArgument(cadence.NewArray(nodeStakingAmounts))
		tx.AddArgument(cadence.NewArray(nodePaths))

		signAndSubmit(
			t, b, tx,
			[]flow.Address{nodeAddress},
			[]crypto.Signer{nodeSigner},
			false,
		)
	})

	t.Run("Should end staking auction with no approved nodes which should not fail because of out of bounds array access", func(t *testing.T) {

		setNodeRoleSlotLimits(t, b, env, idTableAddress, IDTableSigner, [5]uint16{5, 5, 5, 5, 2})

		scriptResult, err := b.ExecuteScript(templates.GenerateEndStakingTestScript(env), nil)
		require.NoError(t, err)
		if !assert.True(t, scriptResult.Succeeded()) {
			t.Log(scriptResult.Error.Error())
		}
	})
}

func TestIDTableUnstakeAllManyDelegators(t *testing.T) {

	t.Parallel()

	b, adapter := newBlockchain(emulator.WithTransactionMaxGasLimit(100000000))

	env := templates.Environment{
		FungibleTokenAddress: emulatorFTAddress,
		FlowTokenAddress:     emulatorFlowTokenAddress,
		BurnerAddress:        emulatorServiceAccount,
		StorageFeesAddress:   emulatorServiceAccount,
	}

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the ID table account
	IDTableAccountKey, IDTableSigner := accountKeys.NewWithSigner()
	idTableAddress, _ := deployStakingContract(t, b, IDTableAccountKey, IDTableSigner, &env, true, []uint64{10000, 10000, 10000, 10000, 10000})

	env.IDTableAddress = idTableAddress.Hex()

	// Change the delegator staking minimum to zero
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateChangeDelegatorMinimumsScript(env), idTableAddress)

	tx.AddArgument(CadenceUFix64("0.0"))

	signAndSubmit(
		t, b, tx,
		[]flow.Address{idTableAddress},
		[]crypto.Signer{IDTableSigner},
		false,
	)

	var nodeAccountKeys [unstakeAllNumNodes]*flow.AccountKey
	var nodeSigners [unstakeAllNumNodes]crypto.Signer
	var nodeAddresses [unstakeAllNumNodes]flow.Address

	// Create many new node accounts for nodes
	for i := 0; i < unstakeAllNumNodes; i++ {
		nodeAccountKeys[i], nodeSigners[i] = accountKeys.NewWithSigner()
		nodeAddresses[i], _ = adapter.CreateAccount(context.Background(), []*flow.AccountKey{nodeAccountKeys[i]}, nil)
	}

	approvedNodes := make([]cadence.Value, unstakeAllNumNodes)

	var delegatorAccountKey *flow.AccountKey
	var delegatorSigner crypto.Signer
	var delegatorAddress flow.Address

	// Create many new delegator accounts
	delegatorAccountKey, delegatorSigner = accountKeys.NewWithSigner()
	delegatorAddress, _ = adapter.CreateAccount(context.Background(), []*flow.AccountKey{delegatorAccountKey}, nil)

	delegatorPaths := make([]cadence.Value, unstakeAllNumDelegators)

	t.Run("Should be able to mint tokens for the nodes", func(t *testing.T) {

		for i := 0; i < unstakeAllNumNodes; i++ {

			script := templates.GenerateMintFlowScript(env)
			tx := createTxWithTemplateAndAuthorizer(b, script, b.ServiceKey().Address)

			_ = tx.AddArgument(cadence.NewAddress(nodeAddresses[i]))
			_ = tx.AddArgument(CadenceUFix64("2000000.0"))

			signAndSubmit(
				t, b, tx,
				[]flow.Address{},
				[]crypto.Signer{},
				false,
			)
		}
	})

	t.Run("Should be able to enable the staking auction", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateStartStakingScript(env), idTableAddress)

		signAndSubmit(
			t, b, tx,
			[]flow.Address{idTableAddress},
			[]crypto.Signer{IDTableSigner},
			false,
		)
	})

	t.Run("Should be able to create many valid Node structs", func(t *testing.T) {

		for i := 0; i < unstakeAllNumNodes; i++ {

			tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateRegisterNodeScript(env), nodeAddresses[i])

			id := fmt.Sprintf("%064d", i)

			approvedNodes[i] = CadenceString(id)

			role := uint8((i % 4) + 1)

			_, stakingKey, stakingKeyPOP, _, networkingKey := generateKeysForNodeRegistration(t)

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
			err = tx.AddArgument(CadenceString(stakingKeyPOP))
			require.NoError(t, err)
			tokenAmount, err := cadence.NewUFix64("1500000.0")
			require.NoError(t, err)
			err = tx.AddArgument(tokenAmount)
			require.NoError(t, err)

			signAndSubmit(
				t, b, tx,
				[]flow.Address{nodeAddresses[i]},
				[]crypto.Signer{nodeSigners[i]},
				false,
			)

		}

	})

	t.Run("Should be able to register many delegators", func(t *testing.T) {

		for i := 0; i < unstakeAllNumDelegators; i++ {

			delegatorPaths[i] = cadence.Path{Domain: common.PathDomainStorage, Identifier: fmt.Sprintf("del%06d", i)}

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
			[]flow.Address{delegatorAddress},
			[]crypto.Signer{delegatorSigner},
			false,
		)
	})

	t.Run("Should be able request unstake all which also requests to unstake all the delegator's tokens", func(t *testing.T) {

		tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateUnstakeAllScript(env), nodeAddresses[0])

		signAndSubmit(
			t, b, tx,
			[]flow.Address{nodeAddresses[0]},
			[]crypto.Signer{nodeSigners[0]},
			false,
		)

	})
}
