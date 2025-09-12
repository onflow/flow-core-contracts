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

access(all) fun testScheduledTransactionCancellationLimits() {

    // lower the canceled transactions limit so the test runs faster
    setConfigDetails(
        maximumIndividualEffort: nil,
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        maxDataSizeMB: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        canceledTransactionsLimit: 10,
        collectionEffortLimit: nil,
        collectionTransactionsLimit: nil,
        shouldFail: nil
    )

    let currentTime = getTimestamp()
    var timeInFuture = currentTime + futureDelta

    let numToCancel: UInt64 = 20
    var i: UInt64 = 0

    // Schedule numToCancel transactions
    while i <= numToCancel {

        // Schedule a medium transaction
        scheduleTransaction(
            timestamp: timeInFuture + UFix64(i),
            fee: feeAmount,
            effort: mediumEffort,
            priority: mediumPriority,
            data: testData,
            testName: "Cancellation Limits: Scheduled \(i)",
            failWithErr: nil
        )

        i = i + 1

    }

    // Cancel the second transaction
    cancelTransaction(
        id: 2,
        failWithErr: nil
    )

    var id: UInt64 = 1

    while id < numToCancel {

        // Cancel the transactions
        if id != 2 {
            cancelTransaction(
                id: id,
                failWithErr: nil
            )
        }

        // make sure the getStatus logic is working correctly
        // the second transaction should be canceled
        if id < 12 {
            Test.assertEqual(statusCanceled, getStatus(id: 2)!)
        } else {
            Test.assertEqual(statusUnknown, getStatus(id: 2)!)
        }

        id = id + 1
    }

    // Check that the canceled transactions are the ones we expect
    var canceledTransactions = getCanceledTransactions()
    Test.assertEqual(10, canceledTransactions.length)

    // The first 10 canceled transactions should have been removed from the canceled transactions array
    i = 10 as UInt64
    for canceledID in canceledTransactions {
        Test.assertEqual(i, canceledID)
        i = i + 1
    }

    // get the status of one of the first 30 transactions and one of the later ones
    var status = getStatus(id: 1)
    Test.assertEqual(statusUnknown, status!)

    status = getStatus(id: 19)
    Test.assertEqual(statusCanceled, status!)

    status = getStatus(id: 20)
    Test.assertEqual(statusScheduled, status!)
}

access(all) fun testScheduledTransactionScheduleAnotherTransaction() {

    if startingHeight < getCurrentBlockHeight() {
        Test.reset(to: startingHeight)
    }

    let currentTime = getTimestamp()
    var timeInFuture = currentTime + futureDelta*5.0

    // Schedule a medium transaction
    scheduleTransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: mediumEffort,
        priority: mediumPriority,
        data: "schedule",
        testName: "Schedule Another Transaction: Scheduled",
        failWithErr: nil
    )

    let transactionData = getTransactionData(id: 1)
    Test.assertEqual(1 as UInt64,transactionData!.id)
    Test.assertEqual(timeInFuture, transactionData!.scheduledTimestamp)
    Test.assertEqual(mediumPriority, transactionData!.priority.rawValue)
    Test.assertEqual(feeAmount, transactionData!.fees)
    Test.assertEqual(mediumEffort, transactionData!.executionEffort)
    Test.assertEqual(statusScheduled, transactionData!.status.rawValue)

    Test.moveTime(by: Fix64(futureDelta*6.0))

    processTransactions()

    executeScheduledTransaction(
        id: 1,
        testName: "Schedule Another Transaction: Executed",
        failWithErr: nil
    )

    // get the status of the newly scheduled transaction with ID 2
    var status = getStatus(id: 2)
    Test.assertEqual(statusScheduled, status!)
    
}


access(all) fun testScheduledTransactionDestroyHandler() {

    if startingHeight < getCurrentBlockHeight() {
        Test.reset(to: startingHeight)
    }

    let currentTime = getTimestamp()
    var timeInFuture = currentTime + futureDelta*10.0

    // Schedule a medium transaction
    scheduleTransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: mediumEffort,
        priority: mediumPriority,
        data: testData,
        testName: "Destroy Handler: Scheduled",
        failWithErr: nil
    )

    // Schedule a medium transaction
    scheduleTransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: mediumEffort,
        priority: mediumPriority,
        data: testData,
        testName: "Destroy Handler: SecondScheduled To Cancel",
        failWithErr: nil
    )

    // Destroy the handler for both transactions
    let destroyHandlerCode = Test.readFile("./transactions/destroy_handler.cdc")
    let executeTx = Test.Transaction(
        code: destroyHandlerCode,
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: []
    )
    var result = Test.executeTransaction(executeTx)
    Test.expect(result, Test.beSucceeded())

    // Cancel the second transaction
    cancelTransaction(
        id: 2,
        failWithErr: nil
    )
    
    // make sure the canceled event was emitted with empty handler values
    let canceledEvents = Test.eventsOfType(Type<FlowTransactionScheduler.Canceled>())
    Test.assertEqual(1, canceledEvents.length)
    let canceledEvent = canceledEvents[0] as! FlowTransactionScheduler.Canceled
    Test.assertEqual(UInt64(2), canceledEvent.id)
    Test.assertEqual(mediumPriority, canceledEvent.priority)
    Test.assertEqual(feeAmount/UFix64(2.0), canceledEvent.feesReturned)
    Test.assertEqual(feeAmount/UFix64(2.0), canceledEvent.feesDeducted)
    Test.assertEqual(Address(0x0000000000000001), canceledEvent.transactionHandlerOwner)
    Test.assertEqual("A.0000000000000001.TestFlowScheduledTransactionHandler.Handler", canceledEvent.transactionHandlerTypeIdentifier)

    Test.moveTime(by: Fix64(futureDelta*11.0))

    processTransactions()

    // The transaction with the handler should not have emitted an event because the handler was destroyed
    let pendingExecutionEvents = Test.eventsOfType(Type<FlowTransactionScheduler.PendingExecution>())
    Test.assertEqual(0, pendingExecutionEvents.length)

    executeScheduledTransaction(
        id: 1,
        testName: "Destroy Handler: Execute",
        failWithErr: "Invalid transaction handler: Could not borrow a reference to the transaction handler"
    )
    
}

access(all) fun testScheduledTransactionEstimateReturnNil() {

    if startingHeight < getCurrentBlockHeight() {
        Test.reset(to: startingHeight)
    }

    let currentTime = getTimestamp()
    var timeInFuture = currentTime + futureDelta*20.0

    // Schedule a high priority transaction
    scheduleTransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: maxEffort,
        priority: highPriority,
        data: testData,
        testName: "Estimate Return Nil: Scheduled 1",
        failWithErr: nil
    )

    // Schedule a high priority transaction
    scheduleTransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: maxEffort,
        priority: highPriority,
        data: testData,
        testName: "Estimate Return Nil: Scheduled 2",
        failWithErr: nil
    )

    // Schedule a high priority transaction
    scheduleTransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: maxEffort,
        priority: highPriority,
        data: testData,
        testName: "Estimate Return Nil: Scheduled 3",
        failWithErr: nil
    )

    let estimate = getEstimate(
        data: testData,
        timestamp: timeInFuture,
        priority: highPriority,
        executionEffort: maxEffort
    )
    
    Test.assertEqual(nil, estimate.flowFee)
    Test.assertEqual(nil, estimate.timestamp)
    Test.assertEqual("Invalid execution effort: \(maxEffort) is greater than the priority's available effort for the requested timestamp.", estimate.error!)
}
