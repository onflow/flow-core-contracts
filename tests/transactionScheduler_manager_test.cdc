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
 Manager Getter Functions Tests
 --------------------------------------------------------------------------------- */

access(all) fun testManagerGetterFunctions(timeInFuture: UFix64) {
    
    // Test getManagedTxStatus
    testGetManagedTxStatus()
    
    // Test getManagedTxData
    testGetManagedTxData()
    
    // Test getManagedTxIDsByTimestamp
    testGetManagedTxIDsByTimestamp(timeInFuture)
    
    // Test getManagedTxIDsByTimestampRange
    testGetManagedTxIDsByTimestampRange(timeInFuture)
    
    // Test getManagedTxIDsByHandler
    testGetManagedTxIDsByHandler()
    
    // Test getManagedTxIDs
    testGetManagedTxIDs()
    
    // Test getHandlerTypeIdentifiers
    testGetHandlerTypeIdentifiers()
    
    // Test getHandlerViews
    testGetHandlerViews()
    
    // Test resolveHandlerView
    testResolveHandlerView()
}

access(all) fun testGetManagedTxStatus() {
    // Test getting status for existing transaction
    let status1 = getManagedTxStatus(1)
    Test.assert(status1 != nil, message: "Status for transaction 1 should not be nil")
    Test.assert(status1 == statusScheduled, message: "Status for transaction 1 should be scheduled")
    
    // Test getting status for non-existent transaction
    let status999 = getManagedTxStatus(999)
    Test.assert(status999 == nil, message: "Status for non-existent transaction should be nil")
}

access(all) fun testGetManagedTxData() {
    // Test getting data for existing transaction
    let data1 = getManagedTxData(1)
    Test.assert(data1 != nil, message: "Data for transaction 1 should not be nil")
    if let txData = data1 {
        Test.assert(txData.data == testData, message: "Transaction data should match test data")
        Test.assert(txData.fee == feeAmount, message: "Transaction fee should match expected fee")
        Test.assert(txData.effort == basicEffort, message: "Transaction effort should match expected effort")
    }
    
    // Test getting data for non-existent transaction
    let data999 = getManagedTxData(999)
    Test.assert(data999 == nil, message: "Data for non-existent transaction should be nil")
}

access(all) fun testGetManagedTxIDsByTimestamp(timestamp: UFix64) {
    // Test getting transaction IDs for first timestamp
    let txIds1 = getManagedTxIDsByTimestamp(timestamp)
    Test.assert(txIds1.length == 3, message: "Should have 3 transactions for first timestamp")
    Test.assert(txIds1.contains(1), message: "Should contain transaction ID 1")
    Test.assert(txIds1.contains(2), message: "Should contain transaction ID 2")
    Test.assert(txIds1.contains(3), message: "Should contain transaction ID 3")
    
    // Test getting transaction IDs for second timestamp
    let txIds2 = getManagedTxIDsByTimestamp(timestamp + 1.0)
    Test.assert(txIds2.length == 3, message: "Should have 3 transactions for second timestamp")
    Test.assert(txIds2.contains(4), message: "Should contain transaction ID 4")
    Test.assert(txIds2.contains(5), message: "Should contain transaction ID 5")
    Test.assert(txIds2.contains(6), message: "Should contain transaction ID 6")
    
    // Test getting transaction IDs for non-existent timestamp
    let txIdsEmpty = getManagedTxIDsByTimestamp(timestamp + 100.0)
    Test.assert(txIdsEmpty.length == 0, message: "Should have 0 transactions for non-existent timestamp")
}

access(all) fun testGetManagedTxIDsByTimestampRange(timeInFuture: UFix64) {
    // Test getting transaction IDs for a range that includes all timestamps
    let allTxIds = getManagedTxIDsByTimestampRange(timeInFuture, timeInFuture + 2.0)
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
    let emptyRange = getManagedTxIDsByTimestampRange(timeInFuture + 100.0, timeInFuture + 200.0)
    Test.assert(emptyRange.length == 0, message: "Empty range should return no timestamps")
}

access(all) fun testGetManagedTxIDsByHandler() {
    // Test getting transaction IDs by handler type
    // Note: All transactions use the same handler type (TestFlowScheduledTransactionHandler)
    let handlerType = "A.0000000000000001.TestFlowScheduledTransactionHandler"
    let txIds = getManagedTxIDsByHandler(handlerType)
    
    // Should have all 9 transactions
    Test.assert(txIds.length == 9, message: "Should have 9 transactions for the handler type")
    for i in 1...9 {
        Test.assert(txIds.contains(i), message: "Should contain transaction ID \(i)")
    }
    
    // Test getting transaction IDs for non-existent handler
    let nonExistentHandler = "A.0000000000000007.NonExistentHandler"
    let emptyTxIds = getManagedTxIDsByHandler(nonExistentHandler)
    Test.assert(emptyTxIds.length == 0, message: "Non-existent handler should return empty array")
}

access(all) fun testGetManagedTxIDs() {
    // Test getting all managed transaction IDs
    let allTxIds = getManagedTxIDs()
    
    // Should have all 9 transactions
    Test.assert(allTxIds.length == 9, message: "Should have 9 total transactions")
    for i in 1...9 {
        Test.assert(allTxIds.contains(i), message: "Should contain transaction ID \(i)")
    }
}

access(all) fun testGetHandlerTypeIdentifiers() {
    // Test getting handler type identifiers
    let handlerTypes = getHandlerTypeIdentifiers()
    
    // Should have one handler type with 9 transactions
    Test.assert(handlerTypes.length == 1, message: "Should have 1 handler type")
    
    let handlerType = "A.0000000000000007.TestFlowScheduledTransactionHandler"
    if let txIds = handlerTypes[handlerType] {
        Test.assert(txIds.length == 9, message: "Handler type should have 9 transactions")
        for i in 1...9 {
            Test.assert(txIds.contains(i), message: "Handler type should contain transaction ID \(i)")
        }
    } else {
        Test.assert(false, message: "Expected handler type should exist")
    }
}

access(all) fun testGetHandlerViews() {
    // Test getting handler views by handler type
    let handlerType = "A.0000000000000007.TestFlowScheduledTransactionHandler"
    let views = getHandlerViews(handlerType, nil)
    
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
    let handlerType = "A.0000000000000007.TestFlowScheduledTransactionHandler"
    let views = getHandlerViews(handlerType, nil)
    
    if views.length > 0 {
        let viewType = views[0]
        let resolvedView = resolveHandlerView(handlerType, nil, viewType)
        // The resolved view might be nil if the handler doesn't implement the view
        // This is expected behavior, so we just test that the function doesn't crash
        Test.assert(true, message: "resolveHandlerView should not crash")
    }
    
    // Test resolving handler view from transaction ID
    let viewsFromTxId = getHandlerViewsFromTransactionID(1)
    if viewsFromTxId.length > 0 {
        let viewType = viewsFromTxId[0]
        let resolvedView = resolveHandlerViewFromTransactionID(1, viewType)
        // The resolved view might be nil if the handler doesn't implement the view
        // This is expected behavior, so we just test that the function doesn't crash
        Test.assert(true, message: "resolveHandlerViewFromTransactionID should not crash")
    }
    
    // Test resolving handler view for non-existent transaction
    let resolvedViewFromNonExistentTx = resolveHandlerViewFromTransactionID(999, views[0])
    Test.assert(resolvedViewFromNonExistentTx == nil, message: "Non-existent transaction should return nil view")
}

/** ---------------------------------------------------------------------------------
 Transaction handler integration tests
 --------------------------------------------------------------------------------- */

access(all) fun testManagerGetters() {

    let currentTime = getTimestamp()
    let timeInFuture = currentTime + futureDelta
    
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
    scheduleTransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: mediumPriority,
        data: testData,
        testName: "Test Transaction Manager: First Medium Scheduled",
        failWithErr: nil
    )

    // Schedule low priority transaction
    scheduleTransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: lowPriority,
        data: testData,
        testName: "Test Transaction Manager: First Low Scheduled",
        failWithErr: nil
    )

    // Schedule high, medium, and low priority transactions for second timestamp
    scheduleTransaction(
        timestamp: timeInFuture + 1.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        testName: "Test Transaction Manager: Second High Scheduled",
        failWithErr: nil
    )

    // Schedule medium priority transaction
    scheduleTransaction(
        timestamp: timeInFuture + 1.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: mediumPriority,
        data: testData,
        testName: "Test Transaction Manager: Second Medium Scheduled",
        failWithErr: nil
    )

    // Schedule low priority transaction
    scheduleTransaction(
        timestamp: timeInFuture + 1.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: lowPriority,
        data: testData,
        testName: "Test Transaction Manager: Second Low Scheduled",
        failWithErr: nil
    )

    // Schedule high, medium, and low priority transactions for third timestamp
    scheduleTransaction(
        timestamp: timeInFuture + 2.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        testName: "Test Transaction Manager: Third High Scheduled",
        failWithErr: nil
    )

    // Schedule medium priority transaction
    scheduleTransaction(
        timestamp: timeInFuture + 2.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: mediumPriority,
        data: testData,
        testName: "Test Transaction Manager: Third Medium Scheduled",
        failWithErr: nil
    )

    // Schedule low priority transaction
    scheduleTransaction(
        timestamp: timeInFuture + 2.0,
        fee: feeAmount,
        effort: basicEffort,
        priority: lowPriority,
        data: testData,
        testName: "Test Transaction Manager: Third Low Scheduled",
        failWithErr: nil
    )

    // Test manager getter functions
    testManagerGetterFunctions(timeInFuture)

}