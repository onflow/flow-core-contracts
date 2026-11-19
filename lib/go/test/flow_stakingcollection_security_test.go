package test

/*
 * Test: MachineAccountInfo nodeID Validation in addNodeObject()
 *
 * TEST BEHAVIOR:
 *   - WITHOUT FIX: Test FAILS (mismatched nodeID accepted)
 *   - WITH FIX:    Test PASSES (mismatched nodeID rejected)
 *
 * ISSUE:
 *   When calling addNodeObject() with a MachineAccountInfo, the nodeID field
 *   inside the MachineAccountInfo should match the node being added. Without
 *   this validation, inconsistent state could occur where a node is associated
 *   with a MachineAccountInfo that belongs to a different node.
 *
 * FIX:
 *   Add validation in addNodeObject() to ensure machineAccountInfo.nodeID
 *   matches the node's ID.
 */

import (
	"context"
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-go-sdk"
	"github.com/onflow/flow-go-sdk/crypto"
	"github.com/stretchr/testify/require"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

// Transaction that attempts to add a node with mismatched MachineAccountInfo
const mismatchedMachineAccountInfoTx = `
import "FlowStakingCollection"

transaction(otherAddress: Address, otherNodeID: String, myNodeID: String) {
    prepare(signer: auth(BorrowValue) &Account) {
        // Get MachineAccountInfo from another node
        let otherInfo = FlowStakingCollection.getMachineAccounts(address: otherAddress)[otherNodeID]
            ?? panic("machine account not found")

        let collectionRef = signer.storage.borrow<
            auth(FlowStakingCollection.CollectionOwner) &FlowStakingCollection.StakingCollection
        >(from: FlowStakingCollection.StakingCollectionStoragePath)
            ?? panic("collection not found")

        // Remove and re-add node with mismatched MachineAccountInfo
        let node <- collectionRef.removeNode(nodeID: myNodeID)

        // This should fail: otherInfo.nodeID != myNodeID
        collectionRef.addNodeObject(<-node!, machineAccountInfo: otherInfo)
    }
}
`

// TestAddNodeObjectRejectsMismatchedMachineAccountInfo verifies that addNodeObject()
// rejects MachineAccountInfo with a nodeID that doesn't match the node being added.
//
// Test behavior:
//   - WITHOUT FIX: Test FAILS (mismatched MachineAccountInfo is accepted)
//   - WITH FIX:    Test PASSES (mismatched MachineAccountInfo is rejected)
func TestAddNodeObjectRejectsMismatchedMachineAccountInfo(t *testing.T) {
	b, adapter, accountKeys, env := newTestSetup(t)

	// Initialize contracts
	idTableAccountKey, idTableSigner := accountKeys.NewWithSigner()
	initializeAllEpochContracts(t, b, idTableAccountKey, idTableSigner, &env,
		startEpochCounter, numEpochViews, numStakingViews, numDKGViews,
		numClusters, randomSource, rewardIncreaseFactor)

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{adminAccountKey}, nil)
	deployAllCollectionContracts(t, b, adapter, accountKeys, &env, adminAddress, adminSigner)

	// Create two accounts
	account1Address, _, account1Signer := newAccountWithAddress(b, accountKeys)
	account2Address, _, account2Signer := newAccountWithAddress(b, accountKeys)

	mintTokensForAccount(t, b, env, account1Address, "600000.0")
	mintTokensForAccount(t, b, env, account2Address, "1000.0")

	node1ID := "1111111111111111111111111111111111111111111111111111111111111111"
	node2ID := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

	// Setup account1 with Consensus node (creates machine account)
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), account1Address)
	signAndSubmit(t, b, tx, []flow.Address{account1Address}, []crypto.Signer{account1Signer}, false)

	_, stakingKey, stakingPOP, _, networkingKey := generateKeysForNodeRegistration(t)
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterNode(env), account1Address)
	tx.AddArgument(CadenceString(node1ID))
	tx.AddArgument(cadence.NewUInt8(2)) // Consensus
	tx.AddArgument(CadenceString(getNetworkingAddress(101)))
	tx.AddArgument(CadenceString(networkingKey))
	tx.AddArgument(CadenceString(stakingKey))
	tx.AddArgument(CadenceString(stakingPOP))
	tx.AddArgument(CadenceUFix64("500000.0"))
	tx.AddArgument(CadenceString("7d5305c22cb7da418396f32c474c6d84b0bb87ca311d6aa6edfd70a1120ded9dc11427ac31261c24e4e7a6c2affea28ff3da7b00fe285029877fb0b5970dc110"))
	tx.AddArgument(cadence.NewUInt8(1))
	tx.AddArgument(cadence.NewUInt8(1))
	signAndSubmit(t, b, tx, []flow.Address{account1Address}, []crypto.Signer{account1Signer}, false)

	// Setup account2 with Access node (no machine account)
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), account2Address)
	signAndSubmit(t, b, tx, []flow.Address{account2Address}, []crypto.Signer{account2Signer}, false)

	_, stakingKey2, stakingPOP2, _, networkingKey2 := generateKeysForNodeRegistration(t)
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterNode(env), account2Address)
	tx.AddArgument(CadenceString(node2ID))
	tx.AddArgument(cadence.NewUInt8(5)) // Access
	tx.AddArgument(CadenceString(getNetworkingAddress(202)))
	tx.AddArgument(CadenceString(networkingKey2))
	tx.AddArgument(CadenceString(stakingKey2))
	tx.AddArgument(CadenceString(stakingPOP2))
	tx.AddArgument(CadenceUFix64("100.0"))
	tx.AddArgument(CadenceString(""))
	tx.AddArgument(cadence.NewUInt8(1))
	tx.AddArgument(cadence.NewUInt8(1))
	signAndSubmit(t, b, tx, []flow.Address{account2Address}, []crypto.Signer{account2Signer}, false)

	// ============================================================
	// Attempt to add node with mismatched MachineAccountInfo
	// ============================================================
	// WITHOUT FIX: Transaction succeeds → test FAILS
	// WITH FIX:    Transaction fails   → test PASSES
	// ============================================================
	tx = createTxWithTemplateAndAuthorizer(b,
		[]byte(templates.ReplaceAddresses(mismatchedMachineAccountInfoTx, env)), account2Address)
	tx.AddArgument(cadence.NewAddress(account1Address))
	tx.AddArgument(CadenceString(node1ID))
	tx.AddArgument(CadenceString(node2ID))

	// This should fail: MachineAccountInfo.nodeID doesn't match the node
	signAndSubmit(t, b, tx,
		[]flow.Address{account2Address},
		[]crypto.Signer{account2Signer},
		true, // shouldFail=true: mismatched nodeID should be rejected
	)
}

// TestAddNodeObjectAcceptsMatchingMachineAccountInfo verifies that addNodeObject()
// accepts MachineAccountInfo when the nodeID matches (legitimate node transfer).
func TestAddNodeObjectAcceptsMatchingMachineAccountInfo(t *testing.T) {
	b, adapter, accountKeys, env := newTestSetup(t)

	idTableAccountKey, idTableSigner := accountKeys.NewWithSigner()
	initializeAllEpochContracts(t, b, idTableAccountKey, idTableSigner, &env,
		startEpochCounter, numEpochViews, numStakingViews, numDKGViews,
		numClusters, randomSource, rewardIncreaseFactor)

	adminAccountKey, adminSigner := accountKeys.NewWithSigner()
	adminAddress, _ := adapter.CreateAccount(context.Background(), []*flow.AccountKey{adminAccountKey}, nil)
	deployAllCollectionContracts(t, b, adapter, accountKeys, &env, adminAddress, adminSigner)

	senderAddress, _, senderSigner := newAccountWithAddress(b, accountKeys)
	receiverAddress, _, receiverSigner := newAccountWithAddress(b, accountKeys)

	mintTokensForAccount(t, b, env, senderAddress, "600000.0")
	mintTokensForAccount(t, b, env, receiverAddress, "10000.0")

	nodeID := "2222222222222222222222222222222222222222222222222222222222222222"
	var machineAccountAddress flow.Address

	// Setup sender with Consensus node
	tx := createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), senderAddress)
	signAndSubmit(t, b, tx, []flow.Address{senderAddress}, []crypto.Signer{senderSigner}, false)

	_, stakingKey, stakingPOP, _, networkingKey := generateKeysForNodeRegistration(t)
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionRegisterNode(env), senderAddress)
	tx.AddArgument(CadenceString(nodeID))
	tx.AddArgument(cadence.NewUInt8(2))
	tx.AddArgument(CadenceString(getNetworkingAddress(301)))
	tx.AddArgument(CadenceString(networkingKey))
	tx.AddArgument(CadenceString(stakingKey))
	tx.AddArgument(CadenceString(stakingPOP))
	tx.AddArgument(CadenceUFix64("500000.0"))
	tx.AddArgument(CadenceString("7d5305c22cb7da418396f32c474c6d84b0bb87ca311d6aa6edfd70a1120ded9dc11427ac31261c24e4e7a6c2affea28ff3da7b00fe285029877fb0b5970dc110"))
	tx.AddArgument(cadence.NewUInt8(1))
	tx.AddArgument(cadence.NewUInt8(1))
	result := signAndSubmit(t, b, tx, []flow.Address{senderAddress}, []crypto.Signer{senderSigner}, false)
	machineAccountAddress = getMachineAccountFromEvent(t, b, env, result)
	mintTokensForAccount(t, b, env, machineAccountAddress, "100.0")

	// Setup receiver
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionSetup(env), receiverAddress)
	signAndSubmit(t, b, tx, []flow.Address{receiverAddress}, []crypto.Signer{receiverSigner}, false)

	// Transfer node (nodeID matches MachineAccountInfo.nodeID)
	tx = createTxWithTemplateAndAuthorizer(b, templates.GenerateCollectionTransferNode(env), senderAddress)
	tx.AddArgument(CadenceString(nodeID))
	tx.AddArgument(cadence.NewAddress(receiverAddress))
	signAndSubmit(t, b, tx, []flow.Address{senderAddress}, []crypto.Signer{senderSigner}, false)

	// Verify receiver has the node
	nodeIDs := executeScriptAndCheck(t, b, templates.GenerateCollectionGetNodeIDsScript(env),
		[][]byte{jsoncdc.MustEncode(cadence.NewAddress(receiverAddress))}).(cadence.Array)
	require.Equal(t, 1, len(nodeIDs.Values))

	// Verify receiver can use the machine account
	tx = createTxWithTemplateAndAuthorizer(b,
		templates.GenerateCollectionWithdrawFromMachineAccountScript(env), receiverAddress)
	tx.AddArgument(CadenceString(nodeID))
	tx.AddArgument(CadenceUFix64("50.0"))
	signAndSubmit(t, b, tx, []flow.Address{receiverAddress}, []crypto.Signer{receiverSigner}, false)

	machineBalance := executeScriptAndCheck(t, b, templates.GenerateGetFlowBalanceScript(env),
		[][]byte{jsoncdc.MustEncode(cadence.NewAddress(machineAccountAddress))})
	assertEqual(t, CadenceUFix64("50.0"), machineBalance)
}
