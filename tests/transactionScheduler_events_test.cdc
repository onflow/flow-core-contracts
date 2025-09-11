import Test
import BlockchainHelpers
import "FlowTransactionScheduler"
import "FlowToken"
import "TestFlowScheduledTransactionHandler"

import "scheduled_transaction_test_helpers.cdc"

access(all) let transactionToFail = 6 as UInt64
access(all) let transactionToCancel = 2 as UInt64

access(all) var startingHeight: UInt64 = 0

access(all) var feesBalanceBefore: UFix64 = 0.0
access(all) var accountBalanceBefore: UFix64 = 0.0

access(all)
fun setup() {

    var err = Test.deployContract(
        name: "FlowTransactionScheduler",
        path: "../contracts/FlowTransactionScheduler.cdc",
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

access(all) fun testTransactionScheduleEventAndData() {

    let currentTime = getTimestamp()
    let timeInFuture = currentTime + futureDelta

    accountBalanceBefore = getBalance(account: serviceAccount.address)
    feesBalanceBefore = getFeesBalance()
    
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

    // Check for Scheduled event using Test.eventsOfType
    var scheduledEvents = Test.eventsOfType(Type<FlowTransactionScheduler.Scheduled>())
    Test.assert(scheduledEvents.length == 1, message: "There should be one Scheduled event but there are \(scheduledEvents.length) events")
    
    var scheduledEvent = scheduledEvents[0] as! FlowTransactionScheduler.Scheduled
    Test.assertEqual(highPriority, scheduledEvent.priority!)
    Test.assertEqual(timeInFuture, scheduledEvent.timestamp!)
    Test.assert(scheduledEvent.executionEffort == 1000, message: "incorrect execution effort")
    Test.assertEqual(feeAmount, scheduledEvent.fees!)
    Test.assertEqual(serviceAccount.address, scheduledEvent.transactionHandlerOwner!)
    Test.assertEqual("A.0000000000000001.TestFlowScheduledTransactionHandler.Handler", scheduledEvent.transactionHandlerTypeIdentifier!)
    
    let transactionID = scheduledEvent.id as UInt64

    // Get scheduled transactions from test transaction handler
    let scheduledTransactions = TestFlowScheduledTransactionHandler.scheduledTransactions.keys
    Test.assert(scheduledTransactions.length == 1, message: "one scheduled transaction")
    
    let scheduled = TestFlowScheduledTransactionHandler.scheduledTransactions[scheduledTransactions[0]]!
    Test.assert(scheduled.id == transactionID, message: "transaction ID mismatch")
    Test.assert(scheduled.timestamp == timeInFuture, message: "incorrect timestamp")

    var status = getStatus(id: transactionID)
    Test.assertEqual(statusScheduled, status!)

    var transactionData = getTransactionData(id: transactionID)
    Test.assertEqual(transactionID, transactionData!.id)
    Test.assertEqual(timeInFuture, transactionData!.scheduledTimestamp)
    Test.assertEqual(highPriority, transactionData!.priority.rawValue)
    Test.assertEqual(feeAmount, transactionData!.fees)
    Test.assertEqual(basicEffort, transactionData!.executionEffort)
    Test.assertEqual(statusScheduled, transactionData!.status.rawValue)
    Test.assertEqual(serviceAccount.address, transactionData!.handlerAddress)
    Test.assertEqual("A.0000000000000001.TestFlowScheduledTransactionHandler.Handler", transactionData!.handlerTypeIdentifier)

    // invalid timeframe should return empty dictionary
    var transactions = getTransactionsForTimeframe(startTimestamp: timeInFuture, endTimestamp: timeInFuture - 1.0)
    Test.assertEqual(0, transactions.keys.length)

    transactions = getTransactionsForTimeframe(startTimestamp: timeInFuture-10.0, endTimestamp: timeInFuture - 1.0)
    Test.assertEqual(0, transactions.keys.length)

    transactions = getTransactionsForTimeframe(startTimestamp: timeInFuture-10.0, endTimestamp: timeInFuture)
    Test.assertEqual(1, transactions.keys.length)
    let transactionsAtFutureTime = transactions[timeInFuture]!
    let highPriorityTransactions = transactionsAtFutureTime[highPriority]!
    Test.assertEqual(1, highPriorityTransactions.length)
    Test.assertEqual(transactionID, highPriorityTransactions[0])

    // Try to execute the transaction, should fail because it isn't pendingExecution
    executeScheduledTransaction(
        id: transactionID,
        testName: "Test Transaction Events Path: First High Scheduled",
        failWithErr: "Invalid ID: Cannot execute transaction with id \(transactionID) because it has incorrect status \(statusScheduled)"
    )
}


access(all) fun testScheduledTransactionCancelationEvents() {

    var currentTime = getTimestamp()
    var timeInFuture = currentTime + futureDelta

    var balanceBefore = getBalance(account: serviceAccount.address)

    // Cancel invalid transaction should fail
    cancelTransaction(
        id: 100,
        failWithErr: "Invalid ID: 100 transaction not found"
    )

    // Schedule a medium transaction
    scheduleTransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: mediumEffort,
        priority: mediumPriority,
        data: testData,
        testName: "Test Transaction Cancelation: First Scheduled",
        failWithErr: nil
    )

    // Cancel the transaction
    cancelTransaction(
        id: transactionToCancel,
        failWithErr: nil
    )

    let canceledEvents = Test.eventsOfType(Type<FlowTransactionScheduler.Canceled>())
    Test.assert(canceledEvents.length == 1, message: "Should only have one Canceled event")
    let canceledEvent = canceledEvents[0] as! FlowTransactionScheduler.Canceled
    Test.assertEqual(transactionToCancel, canceledEvent.id)
    Test.assertEqual(mediumPriority, canceledEvent.priority)
    Test.assertEqual(feeAmount/UFix64(2.0), canceledEvent.feesReturned)
    Test.assertEqual(feeAmount/UFix64(2.0), canceledEvent.feesDeducted)
    Test.assertEqual(serviceAccount.address, canceledEvent.transactionHandlerOwner)
    Test.assertEqual("A.0000000000000001.TestFlowScheduledTransactionHandler.Handler", canceledEvent.transactionHandlerTypeIdentifier!)

    // Make sure the status is canceled
    var status = getStatus(id: transactionToCancel)
    Test.assertEqual(statusCanceled, status!)

    // Available Effort should be completely unused
    // for the slot that the canceled transaction was in
    var effort = getSlotAvailableEffort(timestamp: timeInFuture, priority: mediumPriority)
    Test.assertEqual(UInt64(mediumPriorityMaxEffort), effort!)

    // Assert that the new balance reflects the refunds
    Test.assertEqual(balanceBefore - feeAmount/UFix64(2.0), getBalance(account: serviceAccount.address))
    Test.assertEqual(feesBalanceBefore + feeAmount/UFix64(2.0), getFeesBalance())
}

access(all) fun testScheduledTransactionExecution() {

    var currentTime = getTimestamp()
    var timeInFuture = currentTime + futureDelta

    feesBalanceBefore = getFeesBalance()

    var scheduledIDs = TestFlowScheduledTransactionHandler.scheduledTransactions.keys

    // Simulate FVM process - should not yet process since timestamp is in the future
    processTransactions()

    // Check that no PendingExecution events were emitted yet (since transaction is in the future)
    let pendingExecutionEventsBeforeTime = Test.eventsOfType(Type<FlowTransactionScheduler.PendingExecution>())
    Test.assert(pendingExecutionEventsBeforeTime.length == 0, message: "PendingExecution before time")

    // move time forward to trigger execution eligibility
    // Have to subtract to handle the automatic timestamp drift
    // so that the medium transaction that got scheduled doesn't get marked as pendingExecution
    Test.moveTime(by: Fix64(futureDelta - 6.0))
    while getTimestamp() < timeInFuture {
        Test.moveTime(by: Fix64(1.0))
    }

    // Simulate FVM process - should process since timestamp is in the past
    processTransactions()

    // Check for PendingExecution event after processing
    // Should have one high

    let pendingExecutionEventsAfterTime = Test.eventsOfType(Type<FlowTransactionScheduler.PendingExecution>())
    Test.assertEqual(1, pendingExecutionEventsAfterTime.length)
    
    var i = 0
    var firstEvent: Bool = false
    for event in pendingExecutionEventsAfterTime {
        let pendingExecutionEvent = event as! FlowTransactionScheduler.PendingExecution
        Test.assert(
            pendingExecutionEvent.id != UInt64(2),
            message: "ID 2 Should not have been marked as pendingExecution"
        )

        // verify that the transactions got marked as executed
        var status = getStatus(id: pendingExecutionEvent.id)
        Test.assertEqual(statusExecuted, status!)

        // Simulate FVM execute - should execute the transaction
        if pendingExecutionEvent.id == transactionToFail {
            // ID 2 should fail, so need to verify that
            executeScheduledTransaction(id: pendingExecutionEvent.id, testName: "Test Transaction Execution: First High Scheduled", failWithErr: "Transaction \(transactionToFail) failed")
        } else {
            executeScheduledTransaction(id: pendingExecutionEvent.id, testName: "Test Transaction Execution: First High Scheduled", failWithErr: nil)
        
            // Verify that the first event is the high priority transaction
            if !firstEvent {
                let executedEvents = Test.eventsOfType(Type<FlowTransactionScheduler.Executed>())
                Test.assert(executedEvents.length == 1, message: "Should only have one Executed event")
                let executedEvent = executedEvents[0] as! FlowTransactionScheduler.Executed
                Test.assertEqual(pendingExecutionEvent.id, executedEvent.id)
                Test.assertEqual(pendingExecutionEvent.priority, executedEvent.priority)
                Test.assertEqual(pendingExecutionEvent.executionEffort, executedEvent.executionEffort)
                Test.assertEqual(pendingExecutionEvent.transactionHandlerOwner, executedEvent.transactionHandlerOwner)
                Test.assertEqual(pendingExecutionEvent.transactionHandlerTypeIdentifier, executedEvent.transactionHandlerTypeIdentifier!)
                firstEvent = true
            }
        }

        i = i + 1
    }

    // Check that the transactions were executed
    var transactionIDs = _executeScript(
        "./scripts/get_executed_transactions.cdc",
        []
    ).returnValue! as! [UInt64]
    Test.assert(transactionIDs.length == 1, message: "Executed ids is the wrong count")
    
    Test.moveTime(by: Fix64(2.0))

    // Process transactions again to remove the executed transactions and pay fees
    processTransactions()

    // Check that the fees were paid
    Test.assertEqual(feesBalanceBefore + feeAmount, getFeesBalance())

    // verify that the removed transaction still counts as executed
    var status = getStatus(id: 1 as UInt64)
    Test.assertEqual(statusExecuted, status!)
}