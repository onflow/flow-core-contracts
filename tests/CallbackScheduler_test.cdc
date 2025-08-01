import Test
import BlockchainHelpers
import "FlowCallbackScheduler"
import "FlowToken"
import "TestFlowCallbackHandler"

// Account 7 is where new contracts are deployed by default
access(all) let admin = Test.getAccount(0x0000000000000007)

access(all) let serviceAccount = Test.serviceAccount()

access(all) let highPriority = UInt8(0)
access(all) let mediumPriority = UInt8(1)
access(all) let lowPriority = UInt8(2)

access(all) let statusScheduled = UInt8(0)
access(all) let statusProcessed = UInt8(1)
access(all) let statusExecuted = UInt8(2)
access(all) let statusCanceled = UInt8(3)

access(all) let basicEffort: UInt64 = 1000
access(all) let mediumEffort: UInt64 = 10000
access(all) let heavyEffort: UInt64 = 20000

access(all) let lowPriorityMaxEffort: UInt64 = 5000
access(all) let mediumPriorityMaxEffort: UInt64 = 15000
access(all) let highPriorityMaxEffort: UInt64 = 30000

access(all) let testData = "test data"
access(all) let failTestData = "fail"

access(all) let callbackToFail = 2 as UInt64

access(all) let futureDelta = 100.0
access(all) var futureTime = 0.0

access(all) var feeAmount = 10.0

access(all) var startingHeight: UInt64 = 0

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
    startingHeight = getCurrentBlock().height

    // Try to process callbacks
    // Nothing will process because nothing is scheduled, but should not fail
    processCallbacks()

    // Try to execute a callback, should fail
    executeCallback(id: UInt64(1), failWithErr: "Invalid ID: Callback with id 1 not found")

    // verify that the available efforts are all their defaults
    var effort = getSlotAvailableEffort(timestamp: futureTime, priority: highPriority)
    Test.assertEqual(30000 as UInt64, effort)

    effort = getSlotAvailableEffort(timestamp: futureTime, priority: mediumPriority)
    Test.assertEqual(15000 as UInt64, effort)

    effort = getSlotAvailableEffort(timestamp: futureTime, priority: lowPriority)
    Test.assertEqual(5000 as UInt64, effort)
}

access(all) fun testGetSizeOfData() {

    // Test different values for data to verify that it reports the correct sizes
    var size = getSizeOfData(data: 1)
    Test.assertEqual(0.00002300 as UFix64, size)

    size = getSizeOfData(data: 100000000)
    Test.assertEqual(0.00002600 as UFix64, size)

    size = getSizeOfData(data: testData)
    Test.assertEqual(0.00003000 as UFix64, size)

    let largeArray: [Int] = []
    while largeArray.length < 10000 {
        largeArray.append(1)
    }

    size = getSizeOfData(data: largeArray)
    Test.assertEqual(0.05286100 as UFix64, size)
}

access(all) fun testCallbackScheduling() {

    let currentTime = getCurrentBlock().timestamp
    futureTime = currentTime + futureDelta

    // Try to schedule callback with insufficient FLOW, should fail
    scheduleCallback(
        timestamp: futureTime,
        fee: 0.0,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        failWithErr: "Insufficient fees: The Fee balance of 0.00000000 is not sufficient to pay the required amount of 0.00010000 for execution of the callback."
    )
    
    // Setup handler and schedule high priority callback
    // using combined transaction with service account
    scheduleCallback(
        timestamp: futureTime,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        failWithErr: nil
    )

    // Check for CallbackScheduled event using Test.eventsOfType
    var scheduledEvents = Test.eventsOfType(Type<FlowCallbackScheduler.CallbackScheduled>())
    Test.assert(scheduledEvents.length == 1, message: "There should be one CallbackScheduled event")
    
    var scheduledEvent = scheduledEvents[0] as! FlowCallbackScheduler.CallbackScheduled
    Test.assertEqual(highPriority, scheduledEvent.priority!)
    Test.assertEqual(futureTime, scheduledEvent.timestamp!)
    Test.assert(scheduledEvent.executionEffort == 1000, message: "incorrect execution effort")
    Test.assertEqual(feeAmount, scheduledEvent.fees!)
    Test.assertEqual(serviceAccount.address, scheduledEvent.callbackOwner!)
    
    let callbackID = scheduledEvent.id as UInt64

    // Get scheduled callbacks from test callback handler
    let scheduledCallbacks = TestFlowCallbackHandler.scheduledCallbacks.keys
    Test.assert(scheduledCallbacks.length == 1, message: "one scheduled callback")
    
    let scheduled = TestFlowCallbackHandler.scheduledCallbacks[scheduledCallbacks[0]]!
    Test.assert(scheduled.id == callbackID, message: "callback ID mismatch")
    Test.assert(scheduled.timestamp == futureTime, message: "incorrect timestamp")

    var status = getStatus(id: callbackID)
    Test.assertEqual(statusScheduled, status)

    // Try to execute the callback, should fail because it isn't processed
    executeCallback(
        id: callbackID,
        failWithErr: "Invalid ID: Cannot execute callback with id \(callbackID) because it has not been processed yet"
    )

    // Schedule another callback, medium this time
    scheduleCallback(
        timestamp: futureTime,
        fee: feeAmount,
        effort: mediumEffort,
        priority: mediumPriority,
        data: "fail",
        failWithErr: nil
    )

    // Schedule another medium callback but it should be put in a future timestamp
    // because it doesn't fit in the requested timestamp
    scheduleCallback(
        timestamp: futureTime,
        fee: feeAmount,
        effort: mediumEffort,
        priority: mediumPriority,
        data: testData,
        failWithErr: nil
    )

    // verify that the main timestamp still has 5000 left for medium
    var effort = getSlotAvailableEffort(timestamp: futureTime, priority: mediumPriority)
    Test.assertEqual(UInt64(5000), effort)

    // verify that the next timestamp has 5000 left after the callback that was moved
    effort = getSlotAvailableEffort(timestamp: futureTime + 1.0, priority: mediumPriority)
    Test.assertEqual(UInt64(5000), effort)

    // Schedule another high callback which should fit
    scheduleCallback(
        timestamp: futureTime,
        fee: feeAmount,
        effort: heavyEffort,
        priority: highPriority,
        data: testData,
        failWithErr: nil
    )

    effort = getSlotAvailableEffort(timestamp: futureTime, priority: highPriority)
    Test.assertEqual(UInt64(4000), effort)

    // Try to schedule another high callback which should fail because it doesn't
    // fit into the requested timestamp
    scheduleCallback(
        timestamp: futureTime,
        fee: feeAmount,
        effort: heavyEffort,
        priority: highPriority,
        data: testData,
        failWithErr: "Invalid execution effort: \(heavyEffort) is greater than the priority's available effort for the requested timestamp."
    )

    // Schedule a low callback that is expected to fit in the `futureTime` slot
    scheduleCallback(
        timestamp: futureTime,
        fee: feeAmount,
        effort: basicEffort,
        priority: lowPriority,
        data: testData,
        failWithErr: nil
    )

    // Make sure the low priority status and available effort
    // for the `futureTime` slot is correct
    status = getStatus(id: UInt64(5))
    Test.assertEqual(statusScheduled, status)

    effort = getSlotAvailableEffort(timestamp: futureTime, priority: lowPriority)
    Test.assertEqual(UInt64(4000), effort!)

    // Schedule a low callback that has an effort of 5000
    // so it will not fit in the `futureTime` slot but will still get scheduled
    scheduleCallback(
        timestamp: futureTime,
        fee: feeAmount,
        effort: lowPriorityMaxEffort,
        priority: lowPriority,
        data: testData,
        failWithErr: nil
    )

    // Make sure the low priority status and available effort
    // for the `futureTime` slot is correct
    status = getStatus(id: UInt64(6))
    Test.assertEqual(statusScheduled, status)

}

access(all) fun testCallbackCancelation() {
    var balanceBefore = getBalance(account: serviceAccount.address)

    // Schedule a medium callback
    scheduleCallback(
        timestamp: futureTime + futureDelta,
        fee: feeAmount,
        effort: mediumEffort,
        priority: mediumPriority,
        data: testData,
        failWithErr: nil
    )

    // Cancel invalid callback should fail
    cancelCallback(
        id: 100,
        failWithErr: "Invalid ID: 100 callback not found"
    )

    // Cancel the callback
    cancelCallback(
        id: 7,
        failWithErr: nil
    )

    let canceledEvents = Test.eventsOfType(Type<FlowCallbackScheduler.CallbackCanceled>())
    Test.assert(canceledEvents.length == 1, message: "Should only have one CallbackCanceled event")
    let canceledEvent = canceledEvents[0] as! FlowCallbackScheduler.CallbackCanceled
    Test.assertEqual(UInt64(7), canceledEvent.id)
    Test.assertEqual(mediumPriority, canceledEvent.priority)
    Test.assertEqual(feeAmount/UFix64(2.0), canceledEvent.feesReturned)
    Test.assertEqual(feeAmount/UFix64(2.0), canceledEvent.feesDeducted)
    Test.assertEqual(serviceAccount.address, canceledEvent.callbackOwner)

    // Make sure the status is canceled
    var status = getStatus(id: UInt64(7))
    Test.assertEqual(statusCanceled, status)

    // Available Effort should be completely unused
    // for the slot that the canceled callback was in
    var effort = getSlotAvailableEffort(timestamp: futureTime + futureDelta, priority: mediumPriority)
    Test.assertEqual(UInt64(mediumPriorityMaxEffort), effort!)

    // Assert that the new balance reflects the refunds
    Test.assertEqual(balanceBefore - feeAmount/UFix64(2.0), getBalance(account: serviceAccount.address))

    // Schedule a high callback in the same slot
    // with max effort that should succeed
    scheduleCallback(
        timestamp: futureTime + futureDelta,
        fee: feeAmount,
        effort: highPriorityMaxEffort,
        priority: highPriority,
        data: testData,
        failWithErr: nil
    )

    // Cancel the callback
    cancelCallback(
        id: 8,
        failWithErr: nil
    )

    // Make sure the status is canceled
    status = getStatus(id: UInt64(8))
    Test.assertEqual(statusCanceled, status)

    // Available Effort should be completely unused
    // for the slot that the canceled callback was in
    effort = getSlotAvailableEffort(timestamp: futureTime + futureDelta, priority: highPriority)
    Test.assertEqual(UInt64(highPriorityMaxEffort), effort!)
    
}

access(all) fun testCallbackExecution() {

    var scheduledIDs = TestFlowCallbackHandler.scheduledCallbacks.keys

    // Simulate FVM process - should not yet process since timestamp is in the future
    processCallbacks()

    // Check that no CallbackProcessed events were emitted yet (since callback is in the future)
    let processedEventsBeforeTime = Test.eventsOfType(Type<FlowCallbackScheduler.CallbackProcessed>())
    Test.assert(processedEventsBeforeTime.length == 0, message: "CallbackProcessed before time")

    // move time forward to trigger execution eligibility
    // Have to subtract four to handle the automatic timestamp drift
    // so that the medium callback that got scheduled doesn't get processed
    Test.moveTime(by: Fix64(futureDelta - 5.0))
    while getTimestamp() < futureTime {
        Test.moveTime(by: Fix64(1.0))
    }

    // Simulate FVM process - should process since timestamp is in the past
    processCallbacks()

    // Check for CallbackProcessed event after processing
    // Should have two high, one medium, and one low
    // and they should be in order
    // Cannot verify the order of events in tests at the moment
    // let expectedEventOrder: [UInt64] = [1, 4, 2, 5]

    let processedEventsAfterTime = Test.eventsOfType(Type<FlowCallbackScheduler.CallbackProcessed>())
    Test.assertEqual(4, processedEventsAfterTime.length)
    
    var i = 0
    var firstEvent: Bool = false
    for event in processedEventsAfterTime {
        let processedEvent = event as! FlowCallbackScheduler.CallbackProcessed
        Test.assert(
            processedEvent.id != UInt64(3),
            message: "ID 3 Should not have been processed"
        )

        // Cannot verify the order in tests at the moment
        // Test.assert(
        //     expectedEventOrder[i] == processedEvent.id,
        //     message: "Events were not processed in priority order. Expected: \(expectedEventOrder[i]), got: \(processedEvent.id)"
        // )

        // verify that the transactions got processed
        var status = getStatus(id: processedEvent.id)
        Test.assertEqual(statusProcessed, status)

        // Simulate FVM execute - should execute the callback
        if processedEvent.id == callbackToFail {
            // ID 2 should fail, so need to verify that
            executeCallback(id: processedEvent.id, failWithErr: "Callback \(callbackToFail) failed")
        } else {
            executeCallback(id: processedEvent.id, failWithErr: nil)
        
            // Verify that the first event is the low priority callback
            if !firstEvent {
                let executedEvents = Test.eventsOfType(Type<FlowCallbackScheduler.CallbackExecuted>())
                Test.assert(executedEvents.length == 1, message: "Should only have one CallbackExecuted event")
                let executedEvent = executedEvents[0] as! FlowCallbackScheduler.CallbackExecuted
                Test.assertEqual(processedEvent.id, executedEvent.id)
                Test.assertEqual(processedEvent.priority, executedEvent.priority)
                Test.assertEqual(processedEvent.executionEffort, executedEvent.executionEffort)
                Test.assertEqual(feeAmount, executedEvent.fees)
                Test.assertEqual(processedEvent.callbackOwner, executedEvent.callbackOwner)
                Test.assertEqual(true, executedEvent.succeeded)
                firstEvent = true
            }
        }

        i = i + 1
    }

    // Check for CallbackExecuted events
    let executedEvents = Test.eventsOfType(Type<FlowCallbackScheduler.CallbackExecuted>())
    Test.assert(executedEvents.length == 3, message: "CallbackExecuted event wrong count")
    
    for event in executedEvents {
        let executedEvent = event as! FlowCallbackScheduler.CallbackExecuted
    
        // Verify callback status is now Executed
        var status = getStatus(id: executedEvent.id)
        Test.assertEqual(statusExecuted, status)
    }

    // Check that the callbacks were executed
    var callbackIDs = executeScript(
        "./scripts/get_executed_callbacks.cdc",
        []
    ).returnValue! as! [UInt64]
    Test.assert(callbackIDs.length == 3, message: "CallbackExecuted ids is the wrong count")


    // Verify failed callback status is still Processed
    var status = getStatus(id: callbackToFail)
    Test.assertEqual(statusProcessed, status)

    // Move time forward by 5 so that
    // the other medium and low priority callbacks get processed
    Test.moveTime(by: Fix64(5.0))

    // Process the two remaining callbacks
    processCallbacks()

    // Execute the two remaining callbacks (medium and low)
    executeCallback(id: UInt64(3), failWithErr: nil)
    executeCallback(id: UInt64(6), failWithErr: nil)
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
            name: "Low priority returns 0.0 timestamp and error",
            timestamp: futureTime,
            priority: FlowCallbackScheduler.Priority.Low,
            executionEffort: 1000,
            data: nil,
            expectedFee: 0.00002,
            expectedTimestamp: 0.0,
            expectedError: "Invalid Priority: Cannot estimate for Low Priority callbacks. They will be included in the first block with available space."
        ),
        EstimateTestCase(
            name: "Past timestamp returns error",
            timestamp: pastTime,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 1000,
            data: nil,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid timestamp: \(pastTime) is in the past, current timestamp: \(currentTime)"
        ),
        EstimateTestCase(
            name: "Current timestamp returns error",
            timestamp: currentTime,
            priority: FlowCallbackScheduler.Priority.Medium,
            executionEffort: 1000,
            data: nil,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid timestamp: \(currentTime) is in the past, current timestamp: \(currentTime)"
        ),
        EstimateTestCase(
            name: "Zero execution effort returns error",
            timestamp: futureTime + 7.0,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 0,
            data: nil,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid execution effort: 0 is less than the minimum execution effort of 5"
        ),
        EstimateTestCase(
            name: "Excessive high priority effort returns error",
            timestamp: futureTime + 8.0,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 50000,
            data: nil,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid execution effort: 50000 is greater than the priority's available effort of 30000"
        ),
        EstimateTestCase(
            name: "Excessive medium priority effort returns error",
            timestamp: futureTime + 9.0,
            priority: FlowCallbackScheduler.Priority.Medium,
            executionEffort: 20000,
            data: nil,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid execution effort: 20000 is greater than the priority's available effort of 15000"
        ),
        EstimateTestCase(
            name: "Excessive low priority effort returns error",
            timestamp: futureTime + 10.0,
            priority: FlowCallbackScheduler.Priority.Low,
            executionEffort: 5001,
            data: nil,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid execution effort: 5001 is greater than the priority's available effort of 5000"
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
            executionEffort: 5,
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
        Test.assert(expectedError == estimate.error, message: "error mismatch for test case: \(testCase.name). Expected \(expectedError) but got \(estimate.error!)")
    } else {
        Test.assert(estimate.error == nil, message: "expected nil error for test case: \(testCase.name)")
    }
}

/** ---------------------------------------------------------------------------------
 Callback scheduler config metadata tests
 --------------------------------------------------------------------------------- */


access(all) fun testConfigMetadata() {

    /** -------------
    Error Test Cases
    ---------------- */
    setConfigMetadata(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: 1.1,
        historicStatusLimit: nil,
        shouldFail: "Invalid refund multiplier: The multiplier must be between 0.0 and 1.0 but got 1.10000000"
    )

    setConfigMetadata(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        historicStatusLimit: 0.0,
        shouldFail: "Invalid historic status limit: Limit must be greater than 1.0 and less than the current timestamp but got 0.00000000"
    )

    setConfigMetadata(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: {highPriority: 20.0, mediumPriority: 10.0, lowPriority: 0.9},
        refundMultiplier: nil,
        historicStatusLimit: nil,
        shouldFail: "Invalid priority fee multiplier: Low priority multiplier must be greater than or equal to 1.0 but got 0.90000000"
    )

    setConfigMetadata(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: {highPriority: 20.0, mediumPriority: 3.0, lowPriority: 4.0},
        refundMultiplier: nil,
        historicStatusLimit: nil,
        shouldFail: "Invalid priority fee multiplier: Medium priority multiplier must be greater than or equal to 4.00000000 but got 3.00000000"
    )

    setConfigMetadata(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: {highPriority: 5.0, mediumPriority: 6.0, lowPriority: 4.0},
        refundMultiplier: nil,
        historicStatusLimit: nil,
        shouldFail: "Invalid priority fee multiplier: High priority multiplier must be greater than or equal to 6.00000000 but got 5.00000000"
    )

    setConfigMetadata(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: {highPriority: 40000, mediumPriority: 30000, lowPriority: 10000},
        priorityEffortLimit: {highPriority: 30000, mediumPriority: 30000, lowPriority: 10000},
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        historicStatusLimit: nil,
        shouldFail: "Invalid priority effort limit: High priority effort limit must be greater than or equal to the priority effort reserve of 40000"
    )

    setConfigMetadata(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: {highPriority: 30000, mediumPriority: 40000, lowPriority: 10000},
        priorityEffortLimit: {highPriority: 30000, mediumPriority: 30000, lowPriority: 10000},
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        historicStatusLimit: nil,
        shouldFail: "Invalid priority effort limit: Medium priority effort limit must be greater than or equal to the priority effort reserve of 40000"
    )

    setConfigMetadata(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: {highPriority: 30000, mediumPriority: 30000, lowPriority: 20000},
        priorityEffortLimit: {highPriority: 30000, mediumPriority: 30000, lowPriority: 10000},
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        historicStatusLimit: nil,
        shouldFail: "Invalid priority effort limit: Low priority effort limit must be greater than or equal to the priority effort reserve of 20000"
    )


    /** -------------
    Valid Test Case
    ---------------- */
    let oldConfig = getConfigMetadata()
    Test.assertEqual(oldConfig.slotTotalEffortLimit, 35000 as UInt64)
    Test.assertEqual(oldConfig.slotSharedEffortLimit, 10000 as UInt64)
    Test.assertEqual(oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.High]!, 20000 as UInt64)
    Test.assertEqual(oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Medium]!, 5000 as UInt64)
    Test.assertEqual(oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Low]!, 0 as UInt64)
    Test.assertEqual(oldConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.High]!, 30000 as UInt64)
    Test.assertEqual(oldConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Medium]!, 15000 as UInt64)
    Test.assertEqual(oldConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Low]!, 5000 as UInt64)
    Test.assertEqual(oldConfig.minimumExecutionEffort, 5 as UInt64)
    Test.assertEqual(oldConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.High]!, 10.0)
    Test.assertEqual(oldConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Medium]!, 5.0)
    Test.assertEqual(oldConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Low]!, 2.0)
    Test.assertEqual(oldConfig.refundMultiplier, 0.5)
    Test.assertEqual(oldConfig.historicStatusLimit, 2592000.00000000)


    setConfigMetadata(
        slotSharedEffortLimit: 20000,
        priorityEffortReserve: nil,
        priorityEffortLimit: {highPriority: 30000, mediumPriority: 30000, lowPriority: 10000},
        minimumExecutionEffort: 10,
        priorityFeeMultipliers: {highPriority: 20.0, mediumPriority: 10.0, lowPriority: 4.0},
        refundMultiplier: nil,
        historicStatusLimit: 2000.0,
        shouldFail: nil
    )

    // Verify new config metadata
    let newConfig = getConfigMetadata()
    Test.assertEqual(newConfig.slotTotalEffortLimit, 45000 as UInt64)
    Test.assertEqual(newConfig.slotSharedEffortLimit, 20000 as UInt64)
    Test.assertEqual(newConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.High]!, oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.High]!)
    Test.assertEqual(newConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Medium]!, oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Medium]!)
    Test.assertEqual(newConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Low]!, oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Low]!)
    Test.assertEqual(newConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.High]!, 30000 as UInt64)
    Test.assertEqual(newConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Medium]!, 30000 as UInt64)
    Test.assertEqual(newConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Low]!, 10000 as UInt64)
    Test.assertEqual(newConfig.minimumExecutionEffort, 10 as UInt64)
    Test.assertEqual(newConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.High]!, 20.0)
    Test.assertEqual(newConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Medium]!, 10.0)
    Test.assertEqual(newConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Low]!, 4.0)
    Test.assertEqual(newConfig.refundMultiplier, oldConfig.refundMultiplier)
    Test.assertEqual(newConfig.historicStatusLimit, 2000.0)
}

// Helper function for scheduling a callback
access(all) fun scheduleCallback(
    timestamp: UFix64,
    fee: UFix64,
    effort: UInt64,
    priority: UInt8,
    data: AnyStruct,
    failWithErr: String?
) {
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/callbackScheduler/schedule_callback.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [timestamp, fee, effort, priority, data],
    )
    var result = Test.executeTransaction(tx)

    if let error = failWithErr {
        Test.expect(result, Test.beFailed())
        Test.assertError(
            result,
            errorMessage: error
        )
    
    } else {
        Test.expect(result, Test.beSucceeded())
    }
}

access(all) fun cancelCallback(id: UInt64, failWithErr: String?) {
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/callbackScheduler/cancel_callback.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [id],
    )
    var result = Test.executeTransaction(tx)

    if let error = failWithErr {
        Test.expect(result, Test.beFailed())
        Test.assertError(
            result,
            errorMessage: error
        )
    
    } else {
        Test.expect(result, Test.beSucceeded())
    }
}

access(all) fun processCallbacks(): Test.TransactionResult {
    let processCallbackCode = Test.readFile("../transactions/callbackScheduler/admin/process_callback.cdc")
    let processTx = Test.Transaction(
        code: processCallbackCode,
        authorizers: [],
        signers: [serviceAccount],
        arguments: []
    )
    let processResult = Test.executeTransaction(processTx)
    Test.expect(processResult, Test.beSucceeded())
    return processResult
}

access(all) fun executeCallback(id: UInt64, failWithErr: String?) {
    let executeCallbackCode = Test.readFile("../transactions/callbackScheduler/admin/execute_callback.cdc")
    let executeTx = Test.Transaction(
        code: executeCallbackCode,
        authorizers: [],
        signers: [serviceAccount],
        arguments: [id]
    )
    var result = Test.executeTransaction(executeTx)
    if let error = failWithErr {
        Test.expect(result, Test.beFailed())
        Test.assertError(
            result,
            errorMessage: error
        )
    } else {
        Test.expect(result, Test.beSucceeded())
    }
}

access(all) fun setConfigMetadata(
    slotSharedEffortLimit: UInt64?,
    priorityEffortReserve: {UInt8: UInt64}?,
    priorityEffortLimit: {UInt8: UInt64}?,
    minimumExecutionEffort: UInt64?,
    priorityFeeMultipliers: {UInt8: UFix64}?,
    refundMultiplier: UFix64?,
    historicStatusLimit: UFix64?,
    shouldFail: String?
) {
    let setConfigMetadataCode = Test.readFile("../transactions/callbackScheduler/admin/set_config_metadata.cdc")
    let setConfigMetadataTx = Test.Transaction(
        code: setConfigMetadataCode,
        authorizers: [admin.address],
        signers: [admin],
        arguments: [slotSharedEffortLimit, priorityEffortReserve, priorityEffortLimit, minimumExecutionEffort, priorityFeeMultipliers, refundMultiplier, historicStatusLimit]
    )
    let setConfigMetadataResult = Test.executeTransaction(setConfigMetadataTx)
    if let error = shouldFail {
        Test.expect(setConfigMetadataResult, Test.beFailed())
        // Check error
        //Test.assert(error == setConfigMetadataResult.error!.message, message: "error mismatch: Expected \(error) but got \(setConfigMetadataResult.error!.message)")
        
        Test.assertError(
            setConfigMetadataResult,
            errorMessage: error
        )
    } else {
        Test.expect(setConfigMetadataResult, Test.beSucceeded())
    }
}

access(all) fun getConfigMetadata(): FlowCallbackScheduler.SchedulerConfig {
    var config = executeScript(
        "../transactions/callbackScheduler/scripts/get_config.cdc",
        []
    ).returnValue! as! FlowCallbackScheduler.SchedulerConfig
    return config
}

access(all) fun getSizeOfData(data: AnyStruct): UFix64 {
    var size = executeScript(
        "./scripts/get_data_size.cdc",
        [data]
    ).returnValue! as! UFix64
    return size
}

access(all) fun getStatus(id: UInt64): UInt8 {
    var status = executeScript(
        "../transactions/callbackScheduler/scripts/get_status.cdc",
        [id]
    ).returnValue! as! UInt8
    return status!
}

access(all) fun getSlotAvailableEffort(timestamp: UFix64, priority: UInt8): UInt64 {
    var effort = executeScript(
        "../transactions/callbackScheduler/scripts/get_slot_available_effort.cdc",
        [timestamp, priority]
    ).returnValue! as! UInt64
    return effort!
}

access(all) fun getTimestamp(): UFix64 {
    var timestamp = executeScript(
        "./scripts/get_timestamp.cdc",
        []
    ).returnValue! as! UFix64
    return timestamp!
}

access(all) fun getBalance(account: Address): UFix64 {
    var balance = executeScript(
        "../transactions/flowToken/scripts/get_balance.cdc",
        [account]
    ).returnValue! as! UFix64
    return balance!
}


