import Test
import BlockchainHelpers
import "FlowCallbackScheduler"
import "FlowToken"
import "TestFlowCallbackHandler"

import "callback_test_helpers.cdc"

access(all)
fun setup() {

    var err = Test.deployContract(
        name: "FlowCallbackScheduler",
        path: "../contracts/FlowCallbackScheduler.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "TestFlowCallbackHandler",
        path: "../contracts/testContracts/TestFlowCallbackHandler.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

}

/** ---------------------------------------------------------------------------------
 Callback handler integration tests
 --------------------------------------------------------------------------------- */


access(all) fun testInit() {

    // Try to process callbacks
    // Nothing will process because nothing is scheduled, but should not fail
    processCallbacks()

    // try to get the status of a callback that is not scheduled yet
    var status = getStatus(id: UInt64(10))
    Test.assertEqual(nil, status)

    // try to get the status of callback with ID 0
    status = getStatus(id: UInt64(0))
    Test.assertEqual(nil, status)

    // Try to execute a callback, should fail
    executeCallback(id: UInt64(1), testName: "testInit", failWithErr: "Invalid ID: Callback with id 1 not found")

    // verify that the available efforts are all their defaults
    var effort = getSlotAvailableEffort(timestamp: futureTime, priority: highPriority)
    Test.assertEqual(highPriorityMaxEffort, effort)

    effort = getSlotAvailableEffort(timestamp: futureTime, priority: mediumPriority)
    Test.assertEqual(mediumPriorityMaxEffort, effort)

    effort = getSlotAvailableEffort(timestamp: futureTime, priority: lowPriority)
    Test.assertEqual(lowPriorityMaxEffort, effort)
}

access(all) fun testGetSizeOfData() {

    // Test different values for data to verify that it reports the correct sizes
    var size = getSizeOfData(data: 1)
    Test.assertEqual(0.00000000 as UFix64, size)

    size = getSizeOfData(data: 100000000)
    Test.assertEqual(0.00000000 as UFix64, size)

    size = getSizeOfData(data: StoragePath(identifier: "scheduledCallbacksStoragePath"))
    Test.assertEqual(0.00005300 as UFix64, size)

    size = getSizeOfData(data: testData)
    Test.assertEqual(0.00003000 as UFix64, size)

    // let largeArray: [Int] = []
    // while largeArray.length < 10000 {
    //     largeArray.append(1)
    // }

    // size = getSizeOfData(data: largeArray)
    // Test.assertEqual(0.05286100 as UFix64, size)
}

/** ---------------------------------------------------------------------------------
 Callback scheduler estimate() tests
 --------------------------------------------------------------------------------- */

// Test case structure for estimate function
access(all) struct EstimateTestCase {
    access(all) let name: String
    access(all) let timestamp: UFix64
    access(all) let priority: FlowCallbackScheduler.Priority
    access(all) let executionEffort: UInt64
    access(all) let data: AnyStruct?
    access(all) let expectedFee: UFix64?
    access(all) let expectedTimestamp: UFix64?
    access(all) let expectedError: String?

    access(all) init(
        name: String,
        timestamp: UFix64,
        priority: FlowCallbackScheduler.Priority,
        executionEffort: UInt64,
        data: AnyStruct?,
        expectedFee: UFix64?,
        expectedTimestamp: UFix64?,
        expectedError: String?
    ) {
        self.name = name
        self.timestamp = timestamp
        self.priority = priority
        self.executionEffort = executionEffort
        self.data = data
        self.expectedFee = expectedFee
        self.expectedTimestamp = expectedTimestamp
        self.expectedError = expectedError
    }
}

access(all) fun testEstimate() {

    let currentTime = getCurrentBlock().timestamp
    let futureTime = currentTime + 100.0
    let pastTime = currentTime - 100.0
    let farFutureTime = currentTime + 10000.0

    let estimateTestCases: [EstimateTestCase] = [
        // Error cases - should return EstimatedCallback with error
        EstimateTestCase(
            name: "Low priority returns requested timestamp and error",
            timestamp: futureTime,
            priority: FlowCallbackScheduler.Priority.Low,
            executionEffort: 1000,
            data: nil,
            expectedFee: 0.00002,
            expectedTimestamp: futureTime,
            expectedError: "Invalid Priority: Cannot estimate for Low Priority callbacks. They will be included in the first block with available space after their requested timestamp."
        ),
        EstimateTestCase(
            name: "Past timestamp returns error",
            timestamp: pastTime,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 1000,
            data: nil,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid timestamp: \(pastTime) is in the past, current timestamp: "
        ),
        EstimateTestCase(
            name: "Current timestamp returns error",
            timestamp: currentTime,
            priority: FlowCallbackScheduler.Priority.Medium,
            executionEffort: 1000,
            data: nil,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid timestamp: \(currentTime) is in the past, current timestamp: "
        ),
        EstimateTestCase(
            name: "Zero execution effort returns error",
            timestamp: futureTime + 7.0,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 0,
            data: nil,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid execution effort: 0 is less than the minimum execution effort of 10"
        ),
        EstimateTestCase(
            name: "Excessive high priority effort returns error",
            timestamp: futureTime + 8.0,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 50000,
            data: nil,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid execution effort: 50000 is greater than the maximum callback effort of 9999"
        ),
        EstimateTestCase(
            name: "Excessive medium priority effort returns error",
            timestamp: futureTime + 9.0,
            priority: FlowCallbackScheduler.Priority.Medium,
            executionEffort: 10000,
            data: nil,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid execution effort: 10000 is greater than the maximum callback effort of 9999"
        ),
        EstimateTestCase(
            name: "Excessive low priority effort returns error",
            timestamp: futureTime + 10.0,
            priority: FlowCallbackScheduler.Priority.Low,
            executionEffort: 5001,
            data: nil,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid execution effort: 5001 is greater than the priority's max effort of 5000"
        ),

        // Valid cases - should return EstimatedCallback with no error
        EstimateTestCase(
            name: "High priority effort",
            timestamp: futureTime + 1.0,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 5000,
            data: nil,
            expectedFee: 0.0001,
            expectedTimestamp: futureTime + 1.0,
            expectedError: nil
        ),
        EstimateTestCase(
            name: "Medium priority minimum effort",
            timestamp: futureTime + 4.0,
            priority: FlowCallbackScheduler.Priority.Medium,
            executionEffort: 10,
            data: nil,
            expectedFee: 0.00005,
            expectedTimestamp: futureTime + 4.0,
            expectedError: nil
        ),
        EstimateTestCase(
            name: "Far future timestamp",
            timestamp: farFutureTime,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 1000,
            data: nil,
            expectedFee: 0.0001,
            expectedTimestamp: farFutureTime,
            expectedError: nil
        ),
        EstimateTestCase(
            name: "String data",
            timestamp: futureTime + 10.0,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 1000,
            data: "string data",
            expectedFee: 0.0001,
            expectedTimestamp: futureTime + 10.0,
            expectedError: nil
        ),
        EstimateTestCase(
            name: "Dictionary data",
            timestamp: futureTime + 11.0,
            priority: FlowCallbackScheduler.Priority.Medium,
            executionEffort: 1000,
            data: {"key": "value"},
            expectedFee: 0.00005,
            expectedTimestamp: futureTime + 11.0,
            expectedError: nil
        ),
        EstimateTestCase(
            name: "Array data",
            timestamp: futureTime + 12.0,
            priority: FlowCallbackScheduler.Priority.Medium,
            executionEffort: 1000,
            data: [1, 2, 3, 4, 5, 6],
            expectedFee: 0.00005,
            expectedTimestamp: futureTime + 12.0,
            expectedError: nil
        )
    ]

    for testCase in estimateTestCases {
        runEstimateTestCase(testCase: testCase)
    }
}

access(all) fun runEstimateTestCase(testCase: EstimateTestCase) {
    let estimate = FlowCallbackScheduler.estimate(
        data: testCase.data,
        timestamp: testCase.timestamp,
        priority: testCase.priority,
        executionEffort: testCase.executionEffort
    )
    
    // Check fee
    if let expectedFee = testCase.expectedFee {
        let fee = estimate.flowFee ?? panic("Couldn't unwrap fee for test case: \(testCase.name)")
        Test.assert(expectedFee == estimate.flowFee, message: "fee mismatch for test case: \(testCase.name). Expected \(expectedFee) but got \(estimate.flowFee!)")
    } else {
        Test.assert(estimate.flowFee == nil, message: "expected nil fee for test case: \(testCase.name)")
    }
    
    // Check timestamp
    if let expectedTimestamp = testCase.expectedTimestamp {
        Test.assert(expectedTimestamp == estimate.timestamp, message: "timestamp mismatch for test case: \(testCase.name)")
    } else {
        Test.assert(estimate.timestamp == nil, message: "expected nil timestamp for test case: \(testCase.name)")
    }
    
    // Check error
    if let expectedError = testCase.expectedError {
        Test.assert(estimate.error!.contains(expectedError), message: "error mismatch for test case: \(testCase.name). Expected \(expectedError) but got \(estimate.error!)")
    } else {
        Test.assert(estimate.error == nil, message: "expected nil error for test case: \(testCase.name)")
    }
}

/** ---------------------------------------------------------------------------------
 Callback scheduler config details tests
 --------------------------------------------------------------------------------- */


access(all) fun testConfigDetails() {

    /** -------------
    Error Test Cases
    ---------------- */
    setConfigDetails(
        maximumIndividualEffort: nil,
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        maxDataSizeMB: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: 1.1,
        canceledCallbacksLimit: nil,
        collectionEffortLimit: nil,
        collectionTransactionsLimit: nil,
        shouldFail: "Invalid refund multiplier: The multiplier must be between 0.0 and 1.0 but got 1.10000000"
    )

    setConfigDetails(
        maximumIndividualEffort: nil,
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        maxDataSizeMB: nil,
        priorityFeeMultipliers: {highPriority: 20.0, mediumPriority: 10.0, lowPriority: 0.9},
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        collectionEffortLimit: nil,
        collectionTransactionsLimit: nil,
        shouldFail: "Invalid priority fee multiplier: Low priority multiplier must be greater than or equal to 1.0 but got 0.90000000"
    )

    setConfigDetails(
        maximumIndividualEffort: nil,
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        maxDataSizeMB: nil,
        priorityFeeMultipliers: {highPriority: 20.0, mediumPriority: 3.0, lowPriority: 4.0},
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        collectionEffortLimit: nil,
        collectionTransactionsLimit: nil,
        shouldFail: "Invalid priority fee multiplier: Medium priority multiplier must be greater than or equal to 4.00000000 but got 3.00000000"
    )

    setConfigDetails(
        maximumIndividualEffort: nil,
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        maxDataSizeMB: nil,
        priorityFeeMultipliers: {highPriority: 5.0, mediumPriority: 6.0, lowPriority: 4.0},
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        collectionEffortLimit: nil,
        collectionTransactionsLimit: nil,
        shouldFail: "Invalid priority fee multiplier: High priority multiplier must be greater than or equal to 6.00000000 but got 5.00000000"
    )

    setConfigDetails(
        maximumIndividualEffort: nil,
        slotSharedEffortLimit: nil,
        priorityEffortReserve: {highPriority: 40000, mediumPriority: 30000, lowPriority: 10000},
        priorityEffortLimit: {highPriority: 30000, mediumPriority: 30000, lowPriority: 10000},
        minimumExecutionEffort: nil,
        maxDataSizeMB: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        collectionEffortLimit: nil,
        collectionTransactionsLimit: nil,
        shouldFail: "Invalid priority effort limit: High priority effort limit must be greater than or equal to the priority effort reserve of 40000"
    )

    setConfigDetails(
        maximumIndividualEffort: nil,
        slotSharedEffortLimit: nil,
        priorityEffortReserve: {highPriority: 30000, mediumPriority: 40000, lowPriority: 10000},
        priorityEffortLimit: {highPriority: 30000, mediumPriority: 30000, lowPriority: 10000},
        minimumExecutionEffort: nil,
        maxDataSizeMB: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        collectionEffortLimit: nil,
        collectionTransactionsLimit: nil,
        shouldFail: "Invalid priority effort limit: Medium priority effort limit must be greater than or equal to the priority effort reserve of 40000"
    )

    setConfigDetails(
        maximumIndividualEffort: nil,
        slotSharedEffortLimit: nil,
        priorityEffortReserve: {highPriority: 30000, mediumPriority: 30000, lowPriority: 20000},
        priorityEffortLimit: {highPriority: 30000, mediumPriority: 30000, lowPriority: 10000},
        minimumExecutionEffort: nil,
        maxDataSizeMB: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        collectionEffortLimit: nil,
        collectionTransactionsLimit: nil,
        shouldFail: "Invalid priority effort limit: Low priority effort limit must be greater than or equal to the priority effort reserve of 20000"
    )

    setConfigDetails(
        maximumIndividualEffort: nil,
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        maxDataSizeMB: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        collectionEffortLimit: 30000 as UInt64,
        collectionTransactionsLimit: nil,
        shouldFail: "Invalid collection effort limit: Collection effort limit must be greater than 35000 but got 30000"
    )

    setConfigDetails(
        maximumIndividualEffort: nil,
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        maxDataSizeMB: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        collectionEffortLimit: nil,
        collectionTransactionsLimit: 0,
        shouldFail: "Invalid collection transactions limit: Collection transactions limit must be greater than 0 but got 0"
    )


    /** -------------
    Valid Test Case
    ---------------- */
    let oldConfig = getConfigDetails()
    Test.assertEqual(9999 as UInt64,oldConfig.maximumIndividualEffort)
    Test.assertEqual(35000 as UInt64,oldConfig.slotTotalEffortLimit)
    Test.assertEqual(10000 as UInt64,oldConfig.slotSharedEffortLimit)
    Test.assertEqual(20000 as UInt64,oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.High]!)
    Test.assertEqual(5000 as UInt64,oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Medium]!)
    Test.assertEqual(0 as UInt64,oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Low]!)
    Test.assertEqual(30000 as UInt64,oldConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.High]!)
    Test.assertEqual(15000 as UInt64,oldConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Medium]!)
    Test.assertEqual(5000 as UInt64,oldConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Low]!)
    Test.assertEqual(10 as UInt64,oldConfig.minimumExecutionEffort)
    Test.assertEqual(3.0,oldConfig.maxDataSizeMB)
    Test.assertEqual(10.0,oldConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.High]!)
    Test.assertEqual(5.0,oldConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Medium]!)
    Test.assertEqual(2.0,oldConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Low]!)
    Test.assertEqual(0.5,oldConfig.refundMultiplier)
    Test.assertEqual(720 as UInt,oldConfig.canceledCallbacksLimit) // 30 days with 1 per hour
    Test.assertEqual(8000000 as UInt64,oldConfig.collectionEffortLimit)
    Test.assertEqual(90 as Int,oldConfig.collectionTransactionsLimit)


    setConfigDetails(
        maximumIndividualEffort: 14999,
        slotSharedEffortLimit: 20000,
        priorityEffortReserve: nil,
        priorityEffortLimit: {highPriority: 30000, mediumPriority: 30000, lowPriority: 10000},
        minimumExecutionEffort: 10,
        maxDataSizeMB: 1.0,
        priorityFeeMultipliers: {highPriority: 20.0, mediumPriority: 10.0, lowPriority: 4.0},
        refundMultiplier: nil,
        canceledCallbacksLimit: 2000,
        collectionEffortLimit: 8000000,
        collectionTransactionsLimit: 90,
        shouldFail: nil
    )

    // Verify new config details
    let newConfig = getConfigDetails()
    Test.assertEqual(14999 as UInt64,newConfig.maximumIndividualEffort)
    Test.assertEqual(45000 as UInt64,newConfig.slotTotalEffortLimit)
    Test.assertEqual(20000 as UInt64,newConfig.slotSharedEffortLimit)
    Test.assertEqual(oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.High]!,newConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.High]!)
    Test.assertEqual(oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Medium]!,newConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Medium]!)
    Test.assertEqual(oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Low]!,newConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Low]!)
    Test.assertEqual(30000 as UInt64,newConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.High]!)
    Test.assertEqual(30000 as UInt64,newConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Medium]!)
    Test.assertEqual(10000 as UInt64,newConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Low]!)
    Test.assertEqual(10 as UInt64,newConfig.minimumExecutionEffort)
    Test.assertEqual(1.0,newConfig.maxDataSizeMB)
    Test.assertEqual(20.0,newConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.High]!)
    Test.assertEqual(10.0,newConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Medium]!)
    Test.assertEqual(4.0,newConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Low]!)
    Test.assertEqual(oldConfig.refundMultiplier,newConfig.refundMultiplier)
    Test.assertEqual(2000 as UInt,newConfig.canceledCallbacksLimit)
    Test.assertEqual(8000000 as UInt64,newConfig.collectionEffortLimit)
    Test.assertEqual(90 as Int,newConfig.collectionTransactionsLimit)
}

/** ---------------------------------------------------------------------------------
 SortedTimestamps struct tests
 --------------------------------------------------------------------------------- */

// Test case structures for table-driven tests
access(all) struct AddTestCase {
    access(all) let name: String
    access(all) let timestampsToAdd: [UFix64]
    access(all) let expectedLength: Int
    access(all) let expectedOrder: [UFix64]?

    access(all) init(name: String, timestampsToAdd: [UFix64], expectedLength: Int, expectedOrder: [UFix64]?) {
        self.name = name
        self.timestampsToAdd = timestampsToAdd
        self.expectedLength = expectedLength
        self.expectedOrder = expectedOrder
    }
}

access(all) struct RemoveTestCase {
    access(all) let name: String
    access(all) let initialTimestamps: [UFix64]
    access(all) let timestampToRemove: UFix64
    access(all) let expectedLength: Int
    access(all) let expectedRemaining: [UFix64]

    access(all) init(name: String, initialTimestamps: [UFix64], timestampToRemove: UFix64, expectedLength: Int, expectedRemaining: [UFix64]) {
        self.name = name
        self.initialTimestamps = initialTimestamps
        self.timestampToRemove = timestampToRemove
        self.expectedLength = expectedLength
        self.expectedRemaining = expectedRemaining
    }
}

access(all) struct PastTestCase {
    access(all) let name: String
    access(all) let timestamps: [UFix64]
    access(all) let current: UFix64
    access(all) let expectedPast: [UFix64]

    access(all) init(name: String, timestamps: [UFix64], current: UFix64, expectedPast: [UFix64]) {
        self.name = name
        self.timestamps = timestamps
        self.current = current
        self.expectedPast = expectedPast
    }
}

access(all) struct CheckTestCase {
    access(all) let name: String
    access(all) let timestamps: [UFix64]
    access(all) let current: UFix64
    access(all) let expected: Bool

    access(all) init(name: String, timestamps: [UFix64], current: UFix64, expected: Bool) {
        self.name = name
        self.timestamps = timestamps
        self.current = current
        self.expected = expected
    }
}

access(all) fun testSortedTimestampsInit() {
    let sortedTimestamps = FlowCallbackScheduler.SortedTimestamps()
    
    // Test that it initializes with empty timestamps
    let pastTimestamps = sortedTimestamps.getBefore(current: 100.0)
    Test.assertEqual(0, pastTimestamps.length)
    
    // Test that check returns false for empty timestamps
    Test.assertEqual(false, sortedTimestamps.hasTimestampsBefore(current: 100.0))
}

access(all) fun testSortedTimestampsAdd() {
    let testCases: [AddTestCase] = [
        AddTestCase(
            name: "Add timestamps in random order",
            timestampsToAdd: [50.0, 30.0, 70.0, 10.0, 40.0],
            expectedLength: 5,
            expectedOrder: [10.0, 30.0, 40.0, 50.0, 70.0]
        ),
        AddTestCase(
            name: "Add duplicate timestamp",
            timestampsToAdd: [30.0, 30.0],
            expectedLength: 2,
            expectedOrder: [30.0, 30.0]
        ),
        AddTestCase(
            name: "Add single timestamp",
            timestampsToAdd: [42.0],
            expectedLength: 1,
            expectedOrder: [42.0]
        ),
        AddTestCase(
            name: "Add already sorted timestamps",
            timestampsToAdd: [10.0, 20.0, 30.0, 40.0],
            expectedLength: 4,
            expectedOrder: [10.0, 20.0, 30.0, 40.0]
        )
    ]

    for testCase in testCases {
        let sortedTimestamps = FlowCallbackScheduler.SortedTimestamps()
        
        // Add all timestamps
        for timestamp in testCase.timestampsToAdd {
            sortedTimestamps.add(timestamp: timestamp)
        }
        
        // Verify result
        let result = sortedTimestamps.getBefore(current: 100.0)
        Test.assertEqual(testCase.expectedLength, result.length)
        
        if let expectedOrder = testCase.expectedOrder {
            for i, expected in expectedOrder {
                Test.assertEqual(expected, result[i])
            }
        }
    }
}

access(all) fun testSortedTimestampsRemove() {
    let testCases: [RemoveTestCase] = [
        RemoveTestCase(
            name: "Remove middle timestamp",
            initialTimestamps: [10.0, 20.0, 30.0, 40.0, 50.0],
            timestampToRemove: 30.0,
            expectedLength: 4,
            expectedRemaining: [10.0, 20.0, 40.0, 50.0]
        ),
        RemoveTestCase(
            name: "Remove first timestamp",
            initialTimestamps: [10.0, 20.0, 30.0],
            timestampToRemove: 10.0,
            expectedLength: 2,
            expectedRemaining: [20.0, 30.0]
        ),
        RemoveTestCase(
            name: "Remove last timestamp",
            initialTimestamps: [10.0, 20.0, 30.0],
            timestampToRemove: 30.0,
            expectedLength: 2,
            expectedRemaining: [10.0, 20.0]
        ),
        RemoveTestCase(
            name: "Remove non-existent timestamp",
            initialTimestamps: [10.0, 20.0],
            timestampToRemove: 99.0,
            expectedLength: 2,
            expectedRemaining: [10.0, 20.0]
        ),
        RemoveTestCase(
            name: "Remove from single element",
            initialTimestamps: [25.0],
            timestampToRemove: 25.0,
            expectedLength: 0,
            expectedRemaining: []
        )
    ]

    for testCase in testCases {
        let sortedTimestamps = FlowCallbackScheduler.SortedTimestamps()
        
        // Add initial timestamps
        for timestamp in testCase.initialTimestamps {
            sortedTimestamps.add(timestamp: timestamp)
        }
        
        // Remove the specified timestamp
        sortedTimestamps.remove(timestamp: testCase.timestampToRemove)
        
        // Verify result
        let result = sortedTimestamps.getBefore(current: 100.0)
        Test.assertEqual(testCase.expectedLength, result.length)
        
        for i, expected in testCase.expectedRemaining {
            Test.assertEqual(expected, result[i])
        }
    }
}

access(all) fun testSortedTimestampsPast() {
    let testCases: [PastTestCase] = [
        PastTestCase(
            name: "Get past timestamps with current = 25.0",
            timestamps: [10.0, 20.0, 30.0, 40.0, 50.0],
            current: 25.0,
            expectedPast: [10.0, 20.0]
        ),
        PastTestCase(
            name: "Get past timestamps with current = 30.0 (inclusive)",
            timestamps: [10.0, 20.0, 30.0, 40.0, 50.0],
            current: 30.0,
            expectedPast: [10.0, 20.0, 30.0]
        ),
        PastTestCase(
            name: "Get past timestamps with current = 0.0 (none)",
            timestamps: [10.0, 20.0, 30.0],
            current: 0.0,
            expectedPast: []
        ),
        PastTestCase(
            name: "Get all timestamps",
            timestamps: [10.0, 20.0, 30.0, 40.0, 50.0],
            current: 100.0,
            expectedPast: [10.0, 20.0, 30.0, 40.0, 50.0]
        ),
        PastTestCase(
            name: "Empty timestamps array",
            timestamps: [],
            current: 50.0,
            expectedPast: []
        ),
        PastTestCase(
            name: "Current exactly between timestamps",
            timestamps: [10.0, 30.0],
            current: 20.0,
            expectedPast: [10.0]
        )
    ]

    for testCase in testCases {
        let sortedTimestamps = FlowCallbackScheduler.SortedTimestamps()
        
        // Add timestamps
        for timestamp in testCase.timestamps {
            sortedTimestamps.add(timestamp: timestamp)
        }
        
        // Get past timestamps
        let result = sortedTimestamps.getBefore(current: testCase.current)
        
        // Verify result
        Test.assertEqual(testCase.expectedPast.length, result.length)
        
        for i, expected in testCase.expectedPast {
            Test.assertEqual(expected, result[i])
        }
    }
}

access(all) fun testSortedTimestampsCheck() {
    let testCases: [CheckTestCase] = [
        CheckTestCase(
            name: "Check on empty array",
            timestamps: [],
            current: 100.0,
            expected: false
        ),
        CheckTestCase(
            name: "Current before first timestamp",
            timestamps: [50.0],
            current: 49.0,
            expected: false
        ),
        CheckTestCase(
            name: "Current equal to first timestamp",
            timestamps: [50.0],
            current: 50.0,
            expected: true
        ),
        CheckTestCase(
            name: "Current after first timestamp",
            timestamps: [50.0],
            current: 51.0,
            expected: true
        ),
        CheckTestCase(
            name: "Multiple timestamps, check before first",
            timestamps: [30.0, 50.0, 70.0],
            current: 29.0,
            expected: false
        ),
        CheckTestCase(
            name: "Multiple timestamps, check equal to first",
            timestamps: [30.0, 50.0, 70.0],
            current: 30.0,
            expected: true
        ),
        CheckTestCase(
            name: "Multiple timestamps, check after all",
            timestamps: [30.0, 50.0, 70.0],
            current: 100.0,
            expected: true
        )
    ]

    for testCase in testCases {
        let sortedTimestamps = FlowCallbackScheduler.SortedTimestamps()
        
        // Add timestamps
        for timestamp in testCase.timestamps {
            sortedTimestamps.add(timestamp: timestamp)
        }
        
        // Check result
        let result = sortedTimestamps.hasTimestampsBefore(current: testCase.current)
        Test.assertEqual(testCase.expected, result)
    }
}

access(all) fun testSortedTimestampsEdgeCases() {
    let sortedTimestamps = FlowCallbackScheduler.SortedTimestamps()
    
    // Test adding timestamps at boundaries
    sortedTimestamps.add(timestamp: 0.1)
    sortedTimestamps.add(timestamp: UFix64.max - 1.0)  // Near max value
    
    let allTimestamps = sortedTimestamps.getBefore(current: UFix64.max)
    Test.assertEqual(2, allTimestamps.length)
    Test.assertEqual(0.1, allTimestamps[0])
    Test.assertEqual(UFix64.max - 1.0, allTimestamps[1])
    
    // Test with many timestamps to verify sorting performance
    let manyTimestamps = FlowCallbackScheduler.SortedTimestamps()
    var i = 100
    while i > 0 {
        manyTimestamps.add(timestamp: UFix64(i))
        i = i - 1
    }
    
    let sortedResult = manyTimestamps.getBefore(current: 200.0)
    Test.assertEqual(100, sortedResult.length)
    
    // Verify first few are sorted correctly
    Test.assertEqual(1.0, sortedResult[0])
    Test.assertEqual(2.0, sortedResult[1])
    Test.assertEqual(3.0, sortedResult[2])
    Test.assertEqual(100.0, sortedResult[99])
}