import Test
import BlockchainHelpers
import "FlowTransactionScheduler"
import "FlowToken"
import "TestFlowScheduledTransactionHandler"

import "scheduled_transaction_test_helpers.cdc"

access(all) let transactionToFail = 6 as UInt64
access(all) let transactionToCancel = 2 as UInt64

access(all) var startingHeight: UInt64 = 0

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

    err = Test.deployContract(
        name: "TestFlowScheduledTransactionHandler",
        path: "../contracts/testContracts/TestFlowScheduledTransactionHandler.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    startingHeight = getCurrentBlockHeight()

}

/** ---------------------------------------------------------------------------------
 Transaction handler integration tests
 --------------------------------------------------------------------------------- */

access(all) fun testManagerGetters() {

    let currentTime = getTimestamp()
    let timeInFuture = currentTime + futureDelta
    
    // Schedule high priority transaction
    scheduleTransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        testName: "Test Transaction Scheduling: First High Scheduled",
        failWithErr: nil
    )
}