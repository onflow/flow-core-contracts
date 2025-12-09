import Test
import BlockchainHelpers
import "FlowTransactionScheduler"
import "FlowToken"
import "FlowTransactionSchedulerUtils"

import "scheduled_transaction_test_helpers.cdc"
import "evm_test_helpers.cdc"

access(all) var startingHeight: UInt64 = 0

access(all) let depositFLOWEnum: UInt8 = 0
access(all) let withdrawFLOWEnum: UInt8 = 1
access(all) let callEnum: UInt8 = 2

access(all)
fun setup() {

    var err = Test.deployContract(
        name: "FlowTransactionScheduler",
        path: "../contracts/FlowTransactionScheduler.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "FlowTransactionSchedulerUtils",
        path: "../contracts/FlowTransactionSchedulerUtils.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    fundAccountWithFlow(to: admin.address, amount: 10000.0)

    startingHeight = getCurrentBlockHeight()

}

/* ---------------------------------------------------------------------------------
 COA HandlerParams Unit Tests
 --------------------------------------------------------------------------------- */

access(all) fun testCOAHandlerParams() {
    // Failure Test Cases

    var params = createCOAHandlerParams(
                            coaTXTypeEnum: 3,
                            revertOnFailure: false,
                            amount: 100.0,
                            callToEVMAddress: nil,
                            data: nil,
                            gasLimit: nil,
                            value: nil,
                            testName: "Test COA HandlerParams: Invalid COA transaction type enum",
                            failWithErr: "Invalid COA transaction type enum")

    params = createCOAHandlerParams(
                            coaTXTypeEnum: depositFLOWEnum,
                            revertOnFailure: false,
                            amount: nil,
                            callToEVMAddress: nil,
                            data: nil,
                            gasLimit: nil,
                            value: nil,
                            testName: "Test COA HandlerParams: Deposit FLOW",
                            failWithErr: "Amount is required for deposit but was not provided")

    params = createCOAHandlerParams(
                            coaTXTypeEnum: withdrawFLOWEnum,
                            revertOnFailure: false,
                            amount: nil,
                            callToEVMAddress: nil,
                            data: nil,
                            gasLimit: nil,
                            value: nil,
                            testName: "Test COA HandlerParams: Withdraw FLOW",
                            failWithErr: "Amount is required for withdrawal but was not provided")

    params = createCOAHandlerParams(
                            coaTXTypeEnum: callEnum,
                            revertOnFailure: false,
                            amount: nil,
                            callToEVMAddress: nil,
                            data: [1, 2, 3],
                            gasLimit: 100000,
                            value: 0,
                            testName: "Test COA HandlerParams: Call with nil EVM address",
                            failWithErr: "Call to EVM address is required for EVM call but was not provided or is invalid length (must be 40 hex chars)")

    params = createCOAHandlerParams(
                            coaTXTypeEnum: callEnum,
                            revertOnFailure: false,
                            amount: nil,
                            callToEVMAddress: "1234567890abcdef1234", // 20 hex chars (invalid - too short)
                            data: [1, 2, 3],
                            gasLimit: 100000,
                            value: 0,
                            testName: "Test COA HandlerParams: Call with invalid EVM address length (too short)",
                            failWithErr: "Call to EVM address is required for EVM call but was not provided or is invalid length (must be 40 hex chars)")

    params = createCOAHandlerParams(
                            coaTXTypeEnum: callEnum,
                            revertOnFailure: false,
                            amount: nil,
                            callToEVMAddress: "1234567890abcdef1234567890abcdef1234567890ab", // 42 hex chars (invalid - too long)
                            data: [1, 2, 3],
                            gasLimit: 100000,
                            value: 0,
                            testName: "Test COA HandlerParams: Call with invalid EVM address length (too long)",
                            failWithErr: "Call to EVM address is required for EVM call but was not provided or is invalid length (must be 40 hex chars)")

    params = createCOAHandlerParams(
                            coaTXTypeEnum: callEnum,
                            revertOnFailure: false,
                            amount: nil,
                            callToEVMAddress: "1234567890abcdef1234567890abcdef12345678", // 40 hex chars (20 bytes when decoded)
                            data: nil,
                            gasLimit: 100000,
                            value: 0,
                            testName: "Test COA HandlerParams: Call with nil data",
                            failWithErr: "Data is required for EVM call but was not provided")

    params = createCOAHandlerParams(
                            coaTXTypeEnum: callEnum,
                            revertOnFailure: false,
                            amount: nil,
                            callToEVMAddress: "1234567890abcdef1234567890abcdef12345678", // 40 hex chars (20 bytes when decoded)
                            data: [1, 2, 3],
                            gasLimit: nil,
                            value: 0,
                            testName: "Test COA HandlerParams: Call with nil gas limit",
                            failWithErr: "Gas limit is required for EVM call but was not provided")

    params = createCOAHandlerParams(
                            coaTXTypeEnum: callEnum,
                            revertOnFailure: false,
                            amount: nil,
                            callToEVMAddress: "1234567890abcdef1234567890abcdef12345678", // 40 hex chars (20 bytes when decoded)
                            data: [1, 2, 3],
                            gasLimit: 100000,
                            value: nil,
                            testName: "Test COA HandlerParams: Call with nil value",
                            failWithErr: "Value is required for EVM call but was not provided")

    // Success Test Case
    params = createCOAHandlerParams(
                            coaTXTypeEnum: callEnum,
                            revertOnFailure: false,
                            amount: nil,
                            callToEVMAddress: "1234567890abcdef1234567890abcdef12345678", // 40 hex chars (20 bytes when decoded)
                            data: [1, 2, 3],
                            gasLimit: 100000,
                            value: 1000000000000000000000, // 1000 FLOW in attoFLOW
                            testName: "Test COA HandlerParams: Successful Params",
                            failWithErr: nil)


}

/** ---------------------------------------------------------------------------------
 Transaction handler integration tests
 --------------------------------------------------------------------------------- */

access(all) fun testCOAScheduledTransactions() {

    let currentTime = getTimestamp()
    let timeInFuture = currentTime + futureDelta

    setupCOATransaction(amount: 100.0)

    // get initial balance of the Flow account
    let accountBalanceBefore = getBalance(account: admin.address)
    Test.assertEqual(9900.0, accountBalanceBefore)

    // Schedule high priority transaction to deposit FLOW to the COA
    scheduleCOATransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        coaTXTypeEnum: depositFLOWEnum,
        revertOnFailure: false,
        amount: 100.0,
        callToEVMAddress: nil,
        data: nil,
        gasLimit: nil,
        value: nil,
        testName: "Test COA Transaction Scheduling: Deposit FLOW",
        failWithErr: nil
    )

    // Schedule high priority transaction to withdraw FLOW from the COA
    scheduleCOATransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        coaTXTypeEnum: withdrawFLOWEnum,
        revertOnFailure: false,
        amount: 0.0,
        callToEVMAddress: nil,
        data: nil,
        gasLimit: nil,
        value: nil,
        testName: "Test COA Transaction Scheduling: Withdraw zero FLOW",
        failWithErr: nil
    )

    // Schedule high priority transaction to withdraw too much FLOW from the COA and should revert
    scheduleCOATransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        coaTXTypeEnum: withdrawFLOWEnum,
        revertOnFailure: true,
        amount: 300.0,
        callToEVMAddress: nil,
        data: nil,
        gasLimit: nil,
        value: nil,
        testName: "Test COA Transaction Scheduling: Withdraw too much FLOW, should revert",
        failWithErr: nil
    )

    // Schedule high priority transaction to withdraw too much FLOW from the COA and should not revert
    scheduleCOATransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        coaTXTypeEnum: withdrawFLOWEnum,
        revertOnFailure: false,
        amount: 300.0,
        callToEVMAddress: nil,
        data: nil,
        gasLimit: nil,
        value: nil,
        testName: "Test COA Transaction Scheduling: Withdraw too much FLOW, should not revert",
        failWithErr: nil
    )

    // Schedule high priority transaction to withdraw enough FLOW
    scheduleCOATransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        coaTXTypeEnum: withdrawFLOWEnum,
        revertOnFailure: false,
        amount: 150.0,
        callToEVMAddress: nil,
        data: nil,
        gasLimit: nil,
        value: nil,
        testName: "Test COA Transaction Scheduling: Withdraw enough FLOW",
        failWithErr: nil
    )

    // Schedule high priority transaction to deposit too much FLOW to the COA and should revert
    scheduleCOATransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        coaTXTypeEnum: depositFLOWEnum,
        revertOnFailure: true,
        amount: 10000000.0,
        callToEVMAddress: nil,
        data: nil,
        gasLimit: nil,
        value: nil,
        testName: "Test COA Transaction Scheduling: Deposit too much FLOW, should revert",
        failWithErr: nil
    )

    // Schedule high priority transaction to deposit too much FLOW to the COA and should not revert
    scheduleCOATransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        coaTXTypeEnum: depositFLOWEnum,
        revertOnFailure: false,
        amount: 10000000.0,
        callToEVMAddress: nil,
        data: nil,
        gasLimit: nil,
        value: nil,
        testName: "Test COA Transaction Scheduling: Deposit too much FLOW, should not revert",
        failWithErr: nil
    )

    // Schedule high priority transaction to transfer FLOW in EVM and revert on failure
    scheduleCOATransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        coaTXTypeEnum: callEnum,
        revertOnFailure: true,
        amount: nil,
        callToEVMAddress: "1234567890abcdef1234567890abcdef12345678", // 40 hex chars (20 bytes when decoded)
        data: [],
        gasLimit: 100000,
        value: 1000000000000000000000, // 1000 FLOW in attoFLOW
        testName: "Test COA Transaction Scheduling: Transfer FLOW in EVM, should revert",
        failWithErr: nil
    )

    // Testing framework error with {String: AnyStruct}
    // // Deposit Too much Flow and not revert
    // let call1: {String: AnyStruct} = {}
    // call1["coaTXTypeEnum"] = depositFLOWEnum
    // call1["revertOnFailure"] = false
    // call1["amount"] = 10000000.0

    // // transfer FLOW in EVM and revert on failure, but should succeed
    // let call2: {String: AnyStruct} = {} 
    // call2["coaTXTypeEnum"] = callEnum
    // call2["revertOnFailure"] = true
    // call2["callToEVMAddress"] = "1234567890abcdef1234567890abcdef12345678"
    // call2["data"] = []
    // call2["gasLimit"] = 100000
    // call2["value"] = 1000000000000000000 // 1 FLOW in attoFLOW

    // let calls: [{String: AnyStruct}] = [call1, call2]

    // // Schedule multiple high priority transactions to deposit FLOW and withdraw FLOW
    // scheduleMultipleCOATransactions(
    //     timestamp: timeInFuture,
    //     fee: feeAmount,
    //     effort: basicEffort,
    //     priority: highPriority,
    //     calls: calls,
    //     testName: "Test COA Transaction Scheduling: Multiple COA Transactions should not revert on failure",
    //     failWithErr: nil
    // )

    Test.moveTime(by: Fix64(futureDelta+10.0))

    processTransactions()

    executeScheduledTransaction(
        id: 1,
        testName: "Test COA Transaction Scheduling: Deposit FLOW",
        failWithErr: nil
    )

    executeScheduledTransaction(
        id: 2,
        testName: "Test COA Transaction Scheduling: Withdraw FLOW",
        failWithErr: nil
    )

    executeScheduledTransaction(
        id: 3,
        testName: "Test COA Transaction Scheduling: Withdraw too much FLOW and revert",
        failWithErr: "have 200000000000000000000 want 300000000000000000000"
    )

    executeScheduledTransaction(
        id: 4,
        testName: "Test COA Transaction Scheduling: Withdraw too much FLOW and not revert",
        failWithErr: nil
    )

    executeScheduledTransaction(
        id: 5,
        testName: "Test COA Transaction Scheduling: Withdraw enough FLOW",
        failWithErr: nil
    )

    executeScheduledTransaction(
        id: 6,
        testName: "Test COA Transaction Scheduling: Deposit too much FLOW and revert",
        failWithErr: "is greater than the balance of the Vault"
    )

    executeScheduledTransaction(
        id: 7,
        testName: "Test COA Transaction Scheduling: Deposit too much FLOW and not revert",
        failWithErr: nil
    )

    executeScheduledTransaction(
        id: 8,
        testName: "Test COA Transaction Scheduling: Transfer too mcuh FLOW in EVM and revert",
        failWithErr: "have 50000000000000000000 want 1000000000000000000000"
    )

    // Testing framework error with {String: AnyStruct}
    // executeScheduledTransaction(
    //     id: 9,
    //     testName: "Test COA Transaction Scheduling: Multiple COA Transactions should not revert on failure",
    //     failWithErr: nil
    // )

    var errorEvents = Test.eventsOfType(Type<FlowTransactionSchedulerUtils.COAHandlerExecutionError>())
    Test.assert(errorEvents.length == 2, message: "There should be two COAHandlerExecutionError events but there are \(errorEvents.length) events")
    var errorEvent = errorEvents[0] as! FlowTransactionSchedulerUtils.COAHandlerExecutionError
    Test.assertEqual(4 as UInt64, errorEvent.id)
    Test.assertEqual(admin.address, errorEvent.owner!)
    Test.assertEqual("Insufficient FLOW in COA vault for withdrawal from COA for scheduled transaction with ID 4 and index 0", errorEvent.errorMessage)

    errorEvent = errorEvents[1] as! FlowTransactionSchedulerUtils.COAHandlerExecutionError
    Test.assertEqual(7 as UInt64, errorEvent.id)
    Test.assertEqual(admin.address, errorEvent.owner!)
    Test.assertEqual("Insufficient FLOW in FlowToken vault for deposit into COA for scheduled transaction with ID 7 and index 0", errorEvent.errorMessage)

    // errorEvent = errorEvents[2] as! FlowTransactionSchedulerUtils.COAHandlerExecutionError
    // Test.assertEqual(9 as UInt64, errorEvent.id)
    // Test.assertEqual(admin.address, errorEvent.owner!)
    // Test.assertEqual("Insufficient FLOW in FlowToken vault for deposit into COA for scheduled transaction with ID 7 and index 0", errorEvent.errorMessage)
    
    let accountBalanceAfter = getBalance(account: admin.address)
    Test.assertEqual(accountBalanceBefore+50.0, accountBalanceAfter)
}
