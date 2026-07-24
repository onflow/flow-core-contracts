import Test
import FlowFees from 0x0000000000000007

// The Cadence testing framework bootstraps FlowFees at 0x0000000000000004,
// but it cannot sign transactions for that account, so these tests deploy
// and test FlowFees on the test admin account 0x0000000000000007 instead.
access(all) let admin = Test.getAccount(0x0000000000000007)
access(all) let serviceAccount = Test.serviceAccount()
access(all) let flowFeesAddress = Address(0x0000000000000007)

access(all) fun setup() {
    // Test.deployContract cannot be used here: it would deploy to FlowFees'
    // testing alias (0x4), which is already occupied by the bootstrap.

    // Contract code deployed via a transaction cannot use string imports,
    // so point them at the framework's bootstrapped core contracts
    var code = Test.readFile("../contracts/FlowFees.cdc")
    code = code.replaceAll(of: "\"FungibleToken\"", with: "FungibleToken from 0x0000000000000002")
    code = code.replaceAll(of: "\"FlowToken\"", with: "FlowToken from 0x0000000000000003")
    code = code.replaceAll(of: "\"FlowStorageFees\"", with: "FlowStorageFees from 0x0000000000000001")

    let addResult = Test.executeTransaction(Test.Transaction(
        code: Test.readFile("./transactions/add_contract.cdc"),
        authorizers: [admin.address],
        signers: [admin],
        arguments: ["FlowFees", code],
    ))
    Test.expect(addResult, Test.beSucceeded())
}

/// Reads a file that imports FlowFees and points the import at the
/// test deployment of FlowFees instead of the bootstrapped one at 0x4
access(all) fun readFileWithTestFlowFees(_ path: String): String {
    return Test.readFile(path)
        .replaceAll(of: "\"FlowFees\"", with: "FlowFees from 0x0000000000000007")
}

access(all) fun getFeeReceiverAddresses(): [Address] {
    let result = Test.executeScript(
        readFileWithTestFlowFees("../transactions/FlowServiceAccount/scripts/get_fee_receiver_addresses.cdc"),
        []
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! [Address]
}

access(all) fun getFeesBalance(): UFix64 {
    let result = Test.executeScript(
        readFileWithTestFlowFees("../transactions/FlowServiceAccount/scripts/get_fees_balance.cdc"),
        []
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UFix64
}

access(all) fun runAddFeeChildAccounts(_ accounts: Int): Test.TransactionResult {
    return Test.executeTransaction(Test.Transaction(
        code: readFileWithTestFlowFees("../transactions/FlowServiceAccount/add_fee_child_accounts.cdc"),
        authorizers: [admin.address],
        signers: [admin],
        arguments: [accounts],
    ))
}

access(all) fun testGetFeeReceiverAddressesWithNoChildAccounts() {
    Test.assertEqual([flowFeesAddress], getFeeReceiverAddresses())
}

access(all) fun testAddChildFeeAccounts() {
    let result = runAddFeeChildAccounts(2)
    Test.expect(result, Test.beSucceeded())

    let addresses = getFeeReceiverAddresses()
    Test.assertEqual(3, addresses.length)
    Test.assertEqual(flowFeesAddress, addresses[0])
    Test.assert(addresses[1] != addresses[2], message: "child fee accounts should be distinct")

    let events = Test.eventsOfType(Type<FlowFees.ChildFeeAccountsChanged>())
    Test.assertEqual(1, events.length)
    let changeEvent = events[0] as! FlowFees.ChildFeeAccountsChanged
    Test.assertEqual([addresses[1], addresses[2]], changeEvent.addresses)
}

access(all) fun testAddMoreChildFeeAccountsAppends() {
    let previousChildren = getFeeReceiverAddresses().slice(from: 1, upTo: 3)

    let result = runAddFeeChildAccounts(1)
    Test.expect(result, Test.beSucceeded())

    let addresses = getFeeReceiverAddresses()
    Test.assertEqual(4, addresses.length)

    let events = Test.eventsOfType(Type<FlowFees.ChildFeeAccountsChanged>())
    Test.assertEqual(2, events.length)
    let changeEvent = events[1] as! FlowFees.ChildFeeAccountsChanged
    // the event contains the full new list of child fee accounts,
    // with the previously added accounts first
    Test.assertEqual([addresses[1], addresses[2], addresses[3]], changeEvent.addresses)
    Test.assertEqual(previousChildren, changeEvent.addresses.slice(from: 0, upTo: 2))
}

access(all) fun testCannotAddZeroChildFeeAccounts() {
    let previousAddresses = getFeeReceiverAddresses()

    let result = runAddFeeChildAccounts(0)
    Test.expect(result, Test.beFailed())
    Test.assertError(result, errorMessage: "must be positive")

    Test.assertEqual(previousAddresses, getFeeReceiverAddresses())
    Test.assertEqual(2, Test.eventsOfType(Type<FlowFees.ChildFeeAccountsChanged>()).length)
}

access(all) fun testFeeBalanceAggregatesChildAccounts() {
    let balanceBefore = getFeesBalance()

    // transfer FLOW straight to a child fee account's public receiver
    let childAddress = getFeeReceiverAddresses()[1]
    let transferResult = Test.executeTransaction(Test.Transaction(
        code: Test.readFile("../transactions/flowToken/transfer_tokens.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [5.0, childAddress],
    ))
    Test.expect(transferResult, Test.beSucceeded())
    Test.assertEqual(balanceBefore + 5.0, getFeesBalance())

    // deposit into the main FlowFees vault
    let depositResult = Test.executeTransaction(Test.Transaction(
        code: readFileWithTestFlowFees("../transactions/FlowServiceAccount/deposit_fees.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [3.0],
    ))
    Test.expect(depositResult, Test.beSucceeded())
    Test.assertEqual(balanceBefore + 8.0, getFeesBalance())
}

access(all) fun testDeductTransactionFeeDepositsToChildAccounts() {
    // fee parameters are not initialized on a fresh FlowFees deployment,
    // so they need to be set before fees can be computed
    let setParamsResult = Test.executeTransaction(Test.Transaction(
        code: readFileWithTestFlowFees("../transactions/FlowServiceAccount/set_tx_fee_parameters.cdc"),
        authorizers: [admin.address],
        signers: [admin],
        arguments: [1.0, 1.0, 1.0],
    ))
    Test.expect(setParamsResult, Test.beSucceeded())

    let balanceBefore = getFeesBalance()

    let result = Test.executeTransaction(Test.Transaction(
        code: Test.readFile("./transactions/deduct_transaction_fee.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [1.0, 1.0],
    ))
    Test.expect(result, Test.beSucceeded())

    // fee = surgeFactor * (inclusionEffort * inclusionEffortCost + executionEffort * executionEffortCost)
    //     = 1.0 * (1.0 * 1.0 + 1.0 * 1.0) = 2.0
    // the fee is deposited to one of the child fee accounts,
    // where getFeeBalance picks it up
    Test.assertEqual(balanceBefore + 2.0, getFeesBalance())
}
