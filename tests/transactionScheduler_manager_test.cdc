import Test
import BlockchainHelpers
import "FlowTransactionScheduler"
import "FlowToken"
import "TestFlowScheduledTransactionHandler"
import "MetadataViews"

import "scheduled_transaction_test_helpers.cdc"

access(all) let transactionToFail = 6 as UInt64
access(all) let transactionToCancel = 2 as UInt64

access(all) var startingHeight: UInt64 = 0

access(all) var timeInFuture: UFix64 = 0.0

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

    fundAccountWithFlow(to: admin.address, amount: 10000.0)

    startingHeight = getCurrentBlockHeight()

}

/** ---------------------------------------------------------------------------------
 Manager Getter Functions Tests
 --------------------------------------------------------------------------------- */

access(all) fun testManagerScheduleByHandler() {

    // lower the canceled transactions limit so the test runs faster
    setConfigDetails(
        maximumIndividualEffort: nil,
        minimumExecutionEffort: nil,
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        lowPriorityEffortLimit: nil,
        maxDataSizeMB: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        canceledTransactionsLimit: 2,
        collectionEffortLimit: nil,
        collectionTransactionsLimit: nil,
        txRemovalLimit: nil,
        shouldFail: nil
    )

    let currentTime = getTimestamp()
    timeInFuture = currentTime + futureDelta
    
    // Schedule high, medium, and low priority transactions for first timestamp
    scheduleTransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        testName: "Test Transaction Manager: First High Scheduled",
        failWithErr: nil
    )

    // Schedule medium priority transaction
    scheduleTransactionByHandler(
        handlerTypeIdentifier: "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler",
        handlerUUID: nil,
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: mediumPriority,
        data: testData,
        testName: "Test Manager Schedule First Medium By Handler",
        failWithErr: nil)

    // Schedule low priority transaction
    scheduleTransactionByHandler(
        handlerTypeIdentifier: "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler",
        handlerUUID: nil,
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: lowPriority,
        data: testData,
        testName: "Test Manager Schedule First Low By Handler",
        failWithErr: nil
    )

    // Schedule high, medium, and low priority transactions for second timestamp
    scheduleTransactionByHandler(
        handlerTypeIdentifier: "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler",
        handlerUUID: nil,
        timestamp: timeInFuture + 1.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        testName: "Test Manager Schedule Second High By Handler",
        failWithErr: nil
    )

    // Schedule medium priority transaction
    scheduleTransactionByHandler(
        handlerTypeIdentifier: "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler",
        handlerUUID: nil,
        timestamp: timeInFuture + 1.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: mediumPriority,
        data: testData,
        testName: "Test Manager Schedule Second Medium By Handler",
        failWithErr: nil
    )

    // Schedule low priority transaction
    scheduleTransactionByHandler(
        handlerTypeIdentifier: "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler",
        handlerUUID: nil,
        timestamp: timeInFuture + 1.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: lowPriority,
        data: testData,
        testName: "Test Manager Schedule Second Low By Handler",
        failWithErr: nil
    )

    // Schedule high, medium, and low priority transactions for third timestamp
    scheduleTransactionByHandler(
        handlerTypeIdentifier: "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler",
        handlerUUID: nil,
        timestamp: timeInFuture + 2.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        testName: "Test Manager Schedule Third High By Handler",
        failWithErr: nil
    )

    // Schedule medium priority transaction
    scheduleTransactionByHandler(
        handlerTypeIdentifier: "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler",
        handlerUUID: nil,
        timestamp: timeInFuture + 2.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: mediumPriority,
        data: testData,
        testName: "Test Manager Schedule Third Medium By Handler",
        failWithErr: nil
    )

    // Schedule low priority transaction
    scheduleTransactionByHandler(
        handlerTypeIdentifier: "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler",
        handlerUUID: nil,
        timestamp: timeInFuture + 2.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: lowPriority,
        data: testData,
        testName: "Test Manager Schedule Third Low By Handler",
        failWithErr: nil
    )

    // Failure Test cases for scheduleByHandler

    // Test invalid handler type identifier
    scheduleTransactionByHandler(
        handlerTypeIdentifier: "A.0000000000000007.TestFlowScheduledTransactionHandler.BadHandler",
        handlerUUID: nil,
        timestamp: timeInFuture + 2.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        testName: "Test Manager Schedule Third High By Handler",
        failWithErr: "Invalid handler type identifier: Handler with type identifier A.0000000000000007.TestFlowScheduledTransactionHandler.BadHandler not found in manager"
    )

    // Test invalid handler UUID
    scheduleTransactionByHandler(
        handlerTypeIdentifier: "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler",
        handlerUUID: 10 as UInt64,
        timestamp: timeInFuture + 2.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        testName: "Test Manager Schedule Third High By Handler",
        failWithErr: "Invalid handler UUID: Handler with type identifier A.0000000000000007.TestFlowScheduledTransactionHandler.Handler and UUID 10 not found in manager"
    )

}

access(all) fun testGetManagedTxStatus() {
    // Test getting status for existing transaction
    let status1 = getManagedTxStatus(2)
    Test.assert(status1 != nil, message: "Status for transaction 2 should not be nil")
    Test.assert(status1 == statusScheduled, message: "Status for transaction 2 should be scheduled")
    
    // Test getting status for non-existent transaction
    let status999 = getManagedTxStatus(999)
    Test.assert(status999 == statusUnknown, message: "Status for non-existent transaction should be nil")
}

access(all) fun testGetManagedTxData() {
    // Test getting data for existing transaction
    let data1 = getManagedTxData(1)
    Test.assert(data1 != nil, message: "Data for transaction 1 should not be nil")
    if let txData = data1 {
        Test.assert(txData.id == 1, message: "Transaction ID should match expected ID")
        Test.assert(txData.priority.rawValue == highPriority, message: "Transaction priority should match expected priority")
        Test.assert(txData.fees == feeAmount, message: "Transaction fee should match expected fee")
        Test.assert(txData.executionEffort == basicEffort, message: "Transaction effort should match expected effort")
    }
    
    // Test getting data for non-existent transaction
    let data999 = getManagedTxData(999)
    Test.assert(data999 == nil, message: "Data for non-existent transaction should be nil")
}

access(all) fun testGetManagedTxIDsByTimestamp() {
    // Test getting transaction IDs for first timestamp
    let txIds1 = getManagedTxIDsByTimestamp(timeInFuture)
    Test.assert(txIds1.length == 3, message: "Should have 3 transactions for first timestamp")
    Test.assert(txIds1.contains(1), message: "Should contain transaction ID 1")
    Test.assert(txIds1.contains(2), message: "Should contain transaction ID 2")
    Test.assert(txIds1.contains(3), message: "Should contain transaction ID 3")
    
    // Test getting transaction IDs for second timestamp
    let txIds2 = getManagedTxIDsByTimestamp(timeInFuture + 1.0)
    Test.assert(txIds2.length == 3, message: "Should have 3 transactions for second timestamp")
    Test.assert(txIds2.contains(4), message: "Should contain transaction ID 4")
    Test.assert(txIds2.contains(5), message: "Should contain transaction ID 5")
    Test.assert(txIds2.contains(6), message: "Should contain transaction ID 6")
    
    // Test getting transaction IDs for non-existent timestamp
    let txIdsEmpty = getManagedTxIDsByTimestamp(timeInFuture + 100.0)
    Test.assert(txIdsEmpty.length == 0, message: "Should have 0 transactions for non-existent timestamp")
}

access(all) fun testGetManagedTxIDsByTimestampRange() {
    // Test getting transaction IDs for a range that includes all timestamps
    let allTxIds = getManagedTxIDsByTimestampRange(startTimestamp: timeInFuture, endTimestamp: timeInFuture + 2.0)
    Test.assert(allTxIds.length == 3, message: "Should have 3 timestamps in range")
    
    // Check first timestamp
    if let firstTimestampTxs = allTxIds[timeInFuture] {
        Test.assert(firstTimestampTxs.length == 3, message: "First timestamp should have 3 transactions")
        Test.assert(firstTimestampTxs.contains(1), message: "First timestamp should contain transaction ID 1")
        Test.assert(firstTimestampTxs.contains(2), message: "First timestamp should contain transaction ID 2")
        Test.assert(firstTimestampTxs.contains(3), message: "First timestamp should contain transaction ID 3")
    } else {
        Test.assert(false, message: "First timestamp should exist in range")
    }
    
    // Check second timestamp
    if let secondTimestampTxs = allTxIds[timeInFuture + 1.0] {
        Test.assert(secondTimestampTxs.length == 3, message: "Second timestamp should have 3 transactions")
        Test.assert(secondTimestampTxs.contains(4), message: "Second timestamp should contain transaction ID 4")
        Test.assert(secondTimestampTxs.contains(5), message: "Second timestamp should contain transaction ID 5")
        Test.assert(secondTimestampTxs.contains(6), message: "Second timestamp should contain transaction ID 6")
    } else {
        Test.assert(false, message: "Second timestamp should exist in range")
    }
    
    // Check third timestamp
    if let thirdTimestampTxs = allTxIds[timeInFuture + 2.0] {
        Test.assert(thirdTimestampTxs.length == 3, message: "Third timestamp should have 3 transactions")
        Test.assert(thirdTimestampTxs.contains(7), message: "Third timestamp should contain transaction ID 7")
        Test.assert(thirdTimestampTxs.contains(8), message: "Third timestamp should contain transaction ID 8")
        Test.assert(thirdTimestampTxs.contains(9), message: "Third timestamp should contain transaction ID 9")
    } else {
        Test.assert(false, message: "Third timestamp should exist in range")
    }
    
    // Test getting transaction IDs for empty range
    let emptyRange = getManagedTxIDsByTimestampRange(startTimestamp: timeInFuture + 100.0, endTimestamp: timeInFuture + 200.0)
    Test.assert(emptyRange.length == 0, message: "Empty range should return no timestamps")
}

access(all) fun testGetManagedTxIDsByHandler() {
    // Test getting transaction IDs by handler type
    // Note: All transactions use the same handler type (TestFlowScheduledTransactionHandler)
    let handlerType = "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler"
    let txIds = getManagedTxIDsByHandler(handlerTypeIdentifier: handlerType, handlerUUID: nil)
    
    // Should have all 9 transactions
    Test.assert(txIds.length == 9, message: "Should have 9 transactions for the handler type but got \(txIds.length)")
    var i: UInt64 = 1
    while i <= 9 {
        Test.assert(txIds.contains(i), message: "Should contain transaction ID \(i)")
        i = i + 1
    }

    // Test getting transaction IDs for handler with invalid UUID
    let invalidUUIDHandler = "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler"
    let emptyTxIds = getManagedTxIDsByHandler(handlerTypeIdentifier: invalidUUIDHandler, handlerUUID: 10 as UInt64)
    Test.assert(emptyTxIds.length == 0, message: "Invalid UUID handler should return empty array")
    
    // Test getting transaction IDs for non-existent handler
    let nonExistentHandler = "A.0000000000000007.NonExistentHandler.Handler"
    let emptyTxIds2 = getManagedTxIDsByHandler(handlerTypeIdentifier: nonExistentHandler, handlerUUID: nil)
    Test.assert(emptyTxIds.length == 0, message: "Non-existent handler should return empty array")
}

access(all) fun testGetManagedTxIDs() {
    // Test getting all managed transaction IDs
    let allTxIds = getManagedTxIDs()
    
    // Should have all 9 transactions
    Test.assert(allTxIds.length == 9, message: "Should have 9 total transactions")
    var i: UInt64 = 1
    while i <= 9 {
        Test.assert(allTxIds.contains(i), message: "Should contain transaction ID \(i)")
        i = i + 1
    }
}

access(all) fun testGetHandlerTypeIdentifiers() {
    // Test getting handler type identifiers
    let handlerTypes = getHandlerTypeIdentifiers()
    
    // Should have one handler type with 9 transactions
    Test.assert(handlerTypes.length == 1, message: "Should have 1 handler type")
    
    let handlerType = "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler"
    if let handlerUUIDs = handlerTypes[handlerType] {
        Test.assert(handlerUUIDs.length == 1, message: "Handler type should have 1 uuid but got \(handlerUUIDs.length)")
    } else {
        Test.assert(false, message: "Expected handler type should exist")
    }
}

access(all) fun testGetHandlerViews() {
    // Test getting handler views by handler type
    let handlerType = "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler"
    let views = getHandlerViews(handlerTypeIdentifier: handlerType, handlerUUID: nil)
    
    // Should return the view types available for this handler
    Test.assert(views.length > 0, message: "Should return view types for handler")
    
    // Test getting handler views from transaction ID
    let viewsFromTxId = getHandlerViewsFromTransactionID(1)
    Test.assert(viewsFromTxId.length > 0, message: "Should return view types from transaction ID")
    
    // Test getting handler views for non-existent transaction
    let viewsFromNonExistentTx = getHandlerViewsFromTransactionID(999)
    Test.assert(viewsFromNonExistentTx.length == 0, message: "Non-existent transaction should return empty views")
}

access(all) fun testResolveHandlerView() {
    // Test resolving handler view by handler type
    let handlerType = "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler"
    let views = getHandlerViews(handlerTypeIdentifier: handlerType, handlerUUID: nil)
    
    if views.length > 0 {
        let viewType = views[0]
        let resolvedView = resolveHandlerView(handlerTypeIdentifier: handlerType, handlerUUID: nil, viewType: viewType)
        // The resolved view might be nil if the handler doesn't implement the view
        // This is expected behavior, so we just test that the function doesn't crash
        Test.assert(true, message: "resolveHandlerView should not crash")
    }
    
    // Test resolving handler view from transaction ID
    let viewsFromTxId = getHandlerViewsFromTransactionID(1)
    if viewsFromTxId.length > 0 {
        let viewType = viewsFromTxId[0]
        let resolvedView = resolveHandlerViewFromTransactionID(id: 1, viewType: viewType)
        // The resolved view might be nil if the handler doesn't implement the view
        // This is expected behavior, so we just test that the function doesn't crash
        Test.assert(true, message: "resolveHandlerViewFromTransactionID should not crash")
    }
    
    // Test resolving handler view for non-existent transaction
    let resolvedViewFromNonExistentTx = resolveHandlerViewFromTransactionID(id: 999, viewType: views[0])
    Test.assert(resolvedViewFromNonExistentTx == nil, message: "Non-existent transaction should return nil view")
}


access(all) fun testManagerCancel() {
    
    // Test canceling enough transactions to trigger the canceled transactions limit
    cancelTransaction(
        id: 1,
        failWithErr: nil
    )

    cancelTransaction(
        id: 4,
        failWithErr: nil
    )

    cancelTransaction(
        id: 7,
        failWithErr: nil
    )

    let status1 = getManagedTxStatus(1)
    Test.assert(status1 != nil, message: "Status for transaction 1 should not be nil")
    Test.assert(status1 == statusUnknown, message: "Status for transaction 1 should be unknown")

    let data4 = getManagedTxData(4)
    Test.assert(data4 == nil, message: "Data for transaction 4 should be nil")

    // Test getting transaction IDs for third timestamp
    let txIds3 = getManagedTxIDsByTimestamp(timeInFuture + 2.0)
    Test.assert(txIds3.length == 2, message: "Should have 2 transactions for third timestamp")
    Test.assert(txIds3.contains(7) == false, message: "Should not contain transaction ID 7")
    Test.assert(txIds3.contains(8), message: "Should contain transaction ID 8")
    Test.assert(txIds3.contains(9), message: "Should contain transaction ID 9")

    // Test getting transaction IDs by handler
    let handlerType = "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler"
    let txIds = getManagedTxIDsByHandler(handlerTypeIdentifier: handlerType, handlerUUID: nil)
    
    // Should have all 6 transactions
    Test.assert(txIds.length == 6, message: "Should have 6 transactions for the handler type but got \(txIds.length)")
    var i: UInt64 = 1
    while i <= 9 {
        if i == 1 || i == 4 || i == 7 {
            Test.assert(!txIds.contains(i), message: "Should not contain transaction ID \(i)")
        } else {
            Test.assert(txIds.contains(i), message: "Should contain transaction ID \(i)")
        }
        i = i + 1
    }

    // Test getting all transaction IDs
    let allTxIds = getManagedTxIDs()
    Test.assert(allTxIds.length == 6, message: "Should have 6 total transactions")
    i = 1
    while i <= 9 {
        if i == 1 || i == 4 || i == 7 {
            Test.assert(!allTxIds.contains(i), message: "Should not contain transaction ID \(i)")
        }
        i = i + 1
    }

    // Test getting handler views from cancelled transaction ID
    let viewsFromTxId = getHandlerViewsFromTransactionID(7)
    Test.assert(viewsFromTxId.length == 0, message: "Should return empty views from transaction ID")
    
    // Test resolving handler view from cancelled transaction ID
    let resolvedViewFromTxId = resolveHandlerViewFromTransactionID(id: 7, viewType: Type<MetadataViews.Display>())
    Test.assert(resolvedViewFromTxId == nil, message: "Should return nil view from transaction ID")
}

access(all) fun testManagerExecuteAndCleanup() {

    // move time until after all the timestamps
    Test.moveTime(by: Fix64(futureDelta + 5.0))

    // get the old timestamps
    let oldTimestamps = getManagerTimestamps()
    Test.assert(oldTimestamps.length == 3, message: "Should have 3 timestamps but got \(oldTimestamps.length)")
    Test.assert(oldTimestamps.contains(timeInFuture), message: "Should contain timestamp \(timeInFuture)")
    Test.assert(oldTimestamps.contains(timeInFuture + 1.0), message: "Should contain timestamp \(timeInFuture + 1.0)")
    Test.assert(oldTimestamps.contains(timeInFuture + 2.0), message: "Should contain timestamp \(timeInFuture + 2.0)")

    // process the transactions
    processTransactions()

    // execute the non-canceled transactions
    executeScheduledTransaction(id: 2, testName: "Test Manager Execute and Cleanup", failWithErr: nil)
    executeScheduledTransaction(id: 3, testName: "Test Manager Execute and Cleanup", failWithErr: nil)
    executeScheduledTransaction(id: 5, testName: "Test Manager Execute and Cleanup", failWithErr: nil)
    executeScheduledTransaction(id: 6, testName: "Test Manager Execute and Cleanup", failWithErr: nil)
    executeScheduledTransaction(id: 8, testName: "Test Manager Execute and Cleanup", failWithErr: nil)
    executeScheduledTransaction(id: 9, testName: "Test Manager Execute and Cleanup", failWithErr: nil)

    // process the transactions again to remove the executed transactions
    processTransactions()

    // schedule a new transaction which will cleanup some of the executed transactions
    scheduleTransaction(
        timestamp: timeInFuture + UFix64(50.0),
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        testName: "Test Manager Execute and Cleanup",
        failWithErr: nil)

    // get the old timestamps, timeInFuture should have been removed
    let timestamps = getManagerTimestamps()
    Test.assert(timestamps.length == 0, message: "Should have 0 timestamps after cleanup but got \(timestamps.length)")

    // get status of id 1
    let status1 = getStatus(id: 1)
    Test.assert(status1 == statusUnknown, message: "Status for transaction 1 should be unknown but got \(status1!)")

    // get canceled transactions
    let canceledTransactions = getCanceledTransactions()
    Test.assert(canceledTransactions.length == 2, message: "Should have 2 canceled transactions but got \(canceledTransactions.length)")
    Test.assert(canceledTransactions.contains(4), message: "Should contain transaction ID 4")
    Test.assert(canceledTransactions.contains(7), message: "Should contain transaction ID 7")

    // check that ID 2 and 3 are no longer in the manager
    let status2 = getManagedTxStatus(2)
    Test.assert(status2 == statusUnknown, message: "Status for transaction 2 should be unknown but got \(status2!)")
    let status3 = getManagedTxStatus(3)
    Test.assert(status3 == statusUnknown, message: "Status for transaction 3 should be unknown but got \(status3!)")

    // check that ID 5, 6, 8, and 9 are still in the manager and executed
    let status5 = getManagedTxStatus(5)
    Test.assert(status5 == statusUnknown, message: "Status for transaction 5 should be unknown but got \(status5!)")
    let status6 = getManagedTxStatus(6)
    Test.assert(status6 == statusUnknown, message: "Status for transaction 6 should be unknown but got \(status6!)")
    let status8 = getManagedTxStatus(8)
    Test.assert(status8 == statusUnknown, message: "Status for transaction 8 should be unknown but got \(status8!)")
    let status9 = getManagedTxStatus(9)
    Test.assert(status9 == statusUnknown, message: "Status for transaction 9 should be unknown but got \(status9!)")

    // test getting data for transactions which were executed and cleaned up
    let data2 = getManagedTxData(2)
    Test.assert(data2 == nil, message: "Data for transaction 2 should be nil")
    let data3 = getManagedTxData(3)
    Test.assert(data3 == nil, message: "Data for transaction 3 should be nil")

    // Test getting transaction IDs for first timestamp
    let txIds1 = getManagedTxIDsByTimestamp(timeInFuture)
    Test.assert(txIds1.length == 0, message: "Should have 0 transactions for first timestamp")

    // Test getting transaction IDs by handler
    let handlerType = "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler"
    let txIds = getManagedTxIDsByHandler(handlerTypeIdentifier: handlerType, handlerUUID: nil)
    
    // Should only have 1 transaction, the one scheduled
    Test.assert(txIds.length == 1, message: "Should have 1 transaction for the handler type but got \(txIds.length)")
    Test.assert(txIds.contains(10), message: "Should contain transaction ID 10")

    // Test getting all transaction IDs
    let allTxIds = getManagedTxIDs()
    Test.assert(allTxIds.length == 1, message: "Should have 1 total transaction")
    Test.assert(allTxIds.contains(10), message: "Should contain transaction ID 10")

    // Test getting handler views from executed and cleaned up transaction ID
    let viewsFromTxId = getHandlerViewsFromTransactionID(3)
    Test.assert(viewsFromTxId.length == 0, message: "Should return empty views from cleaned up transaction ID 3")
    
    // Test resolving handler view from executed and cleaned up transaction ID
    let resolvedViewFromTxId = resolveHandlerViewFromTransactionID(id: 3, viewType: Type<MetadataViews.Display>())
    Test.assert(resolvedViewFromTxId == nil, message: "Should return nil view from cleaned up transaction ID 3")
}

access(all) fun testManagerScheduleDifferentUUID() {

    // schedule a transaction with the same handler type but different handler UUID
    let handlerType = "A.0000000000000007.TestFlowScheduledTransactionHandler.Handler"
    var tx = Test.Transaction(
        code: Test.readFile("./transactions/schedule_tx_with_different_handler.cdc"),
        authorizers: [admin.address],
        signers: [admin],
        arguments: [timeInFuture + UFix64(50.0), feeAmount, basicEffort, highPriority, testData],
    )
    var result = Test.executeTransaction(tx)
    Test.expect(result, Test.beSucceeded())

    // schedule a transaction with the same handler by type but nil uuid
    // Should fail because there are two uuids for the handler type
    tx = Test.Transaction(
        code: Test.readFile("../transactions/transactionScheduler/schedule_transaction_by_handler.cdc"),
        authorizers: [admin.address],
        signers: [admin],
        arguments: [handlerType, nil, timeInFuture + UFix64(50.0), feeAmount, basicEffort, highPriority, testData],
    )
    result = Test.executeTransaction(tx)
    Test.expect(result, Test.beFailed())
    Test.assertError(result, errorMessage: "Invalid handler UUID: Handler with type identifier A.0000000000000007.TestFlowScheduledTransactionHandler.Handler has more than one UUID, but no UUID was provided")

    

    // get the handler type identifiers
    let handlerTypeIdentifiers = getHandlerTypeIdentifiers()
    Test.assert(handlerTypeIdentifiers.length == 1, message: "Should have 1 handler type identifier but got \(handlerTypeIdentifiers.length)")
    Test.assert(handlerTypeIdentifiers.containsKey(handlerType), message: "Should contain handler type \(handlerType)")
    let handlerUUIDs = handlerTypeIdentifiers[handlerType]!
    Test.assert(handlerUUIDs.length == 2, message: "Should have 2 handler UUIDs but got \(handlerUUIDs.length)")

    // schedule a transaction with the same handler by type and uuid
    tx = Test.Transaction(
        code: Test.readFile("../transactions/transactionScheduler/schedule_transaction_by_handler.cdc"),
        authorizers: [admin.address],
        signers: [admin],
        arguments: [handlerType, handlerUUIDs[0], timeInFuture + UFix64(50.0), feeAmount, basicEffort, highPriority, testData],
    )
    result = Test.executeTransaction(tx)
    Test.expect(result, Test.beSucceeded())

    // verify that both uuids are represented in the manager
    
    var txIds = getManagedTxIDsByHandler(handlerTypeIdentifier: handlerType, handlerUUID: nil)
    Test.assert(txIds.length == 0, message: "Should have 0 transactions for the handler type because there are two uuids but got \(txIds.length)")

    txIds = getManagedTxIDsByHandler(handlerTypeIdentifier: handlerType, handlerUUID: handlerUUIDs[0])
    Test.assert(txIds.length > 0, message: "Should have more than 0 transactions for the handler type with uuid \(handlerUUIDs[0]) but got \(txIds.length)")

    txIds = getManagedTxIDsByHandler(handlerTypeIdentifier: handlerType, handlerUUID: handlerUUIDs[1])
    Test.assert(txIds.length > 0, message: "Should have more than 0 transactions for the handler type with uuid \(handlerUUIDs[1]) but got \(txIds.length)")

    // Get handler views with nil uuid
    let views = getHandlerViews(handlerTypeIdentifier: handlerType, handlerUUID: nil)
    Test.assert(views.length == 0, message: "Should have 0 views for the handler type with nil uuid but got \(views.length)")

    // Get handler views with uuid
    let views2 = getHandlerViews(handlerTypeIdentifier: handlerType, handlerUUID: handlerUUIDs[0])
    Test.assert(views2.length > 0, message: "Should have more than 0 views for the handler type with uuid \(handlerUUIDs[0]) but got \(views2.length)")
    
}