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

access(all) let statusUnknown = UInt8(0)
access(all) let statusScheduled = UInt8(1)
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
access(all) let callbackToCancel = 8 as UInt64

access(all) let futureDelta = 100.0
access(all) var futureTime = 0.0
access(all) let historicGarbageCollectionLimit = 30.0 * 24.0 * 60.0 * 60.0
access(all) var timeAfterGarbageCollection = 0.0

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

    // err = Test.deployContract(
    //     name: "TestFlowCallbackQueue",
    //     path: "../contracts/testContracts/TestFlowCallbackQueue.cdc",
    //     arguments: []
    // )
    // Test.expect(err, Test.beNil())
}

/** ---------------------------------------------------------------------------------
 Callback handler integration tests
 --------------------------------------------------------------------------------- */


access(all) fun testInit() {

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
    Test.assertEqual(0.00000000 as UFix64, size)

    size = getSizeOfData(data: 100000000)
    Test.assertEqual(0.00000000 as UFix64, size)

    size = getSizeOfData(data: StoragePath(identifier: "scheduledCallbacksStoragePath"))
    Test.assertEqual(0.00005300 as UFix64, size)

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

    startingHeight = getCurrentBlock().height

    let currentTime = getCurrentBlock().timestamp
    futureTime = currentTime + futureDelta

    timeAfterGarbageCollection = futureTime + historicGarbageCollectionLimit

    // Try to schedule callback with insufficient FLOW, should fail
    scheduleCallback(
        timestamp: futureTime,
        fee: 0.0,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        failWithErr: "Insufficient fees: The Fee balance of 0.00000000 is not sufficient to pay the required amount of 0.00010000 for execution of the callback."
    )
    
    // Schedule high priority callback
    scheduleCallback(
        timestamp: futureTime,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        failWithErr: nil
    )

    // Check for Scheduled event using Test.eventsOfType
    var scheduledEvents = Test.eventsOfType(Type<FlowCallbackScheduler.Scheduled>())
    Test.assert(scheduledEvents.length == 1, message: "There should be one Scheduled event")
    
    var scheduledEvent = scheduledEvents[0] as! FlowCallbackScheduler.Scheduled
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

    // Try to execute the callback, should fail because it isn't pendingExecution
    executeCallback(
        id: callbackID,
        failWithErr: "Invalid ID: Cannot execute callback with id \(callbackID) because it has incorrect status \(statusScheduled)"
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

    // Schedule a low callback that has an effort of 5000 for a timestamp after `futureTime`
    // so it would fit in the `futureTime` slot but will not be executed until later
    // because it is a low priority callback and not scheduled for `futureTime`
    scheduleCallback(
        timestamp: futureTime + 200.0,
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

    effort = getSlotAvailableEffort(timestamp: futureTime, priority: lowPriority)
    Test.assertEqual(UInt64(4000), effort!)

}

access(all) fun testCallbackCancelation() {
    var balanceBefore = getBalance(account: serviceAccount.address)

    // Cancel invalid callback should fail
    cancelCallback(
        id: 100,
        failWithErr: "Invalid ID: 100 callback not found"
    )

    // Schedule a medium callback
    scheduleCallback(
        timestamp: futureTime + futureDelta,
        fee: feeAmount,
        effort: mediumEffort,
        priority: mediumPriority,
        data: testData,
        failWithErr: nil
    )

    // Cancel the callback
    cancelCallback(
        id: callbackToCancel,
        failWithErr: nil
    )

    let canceledEvents = Test.eventsOfType(Type<FlowCallbackScheduler.Canceled>())
    Test.assert(canceledEvents.length == 1, message: "Should only have one Canceled event")
    let canceledEvent = canceledEvents[0] as! FlowCallbackScheduler.Canceled
    Test.assertEqual(callbackToCancel, canceledEvent.id)
    Test.assertEqual(mediumPriority, canceledEvent.priority)
    Test.assertEqual(feeAmount/UFix64(2.0), canceledEvent.feesReturned)
    Test.assertEqual(feeAmount/UFix64(2.0), canceledEvent.feesDeducted)
    Test.assertEqual(serviceAccount.address, canceledEvent.callbackOwner)

    // Make sure the status is canceled
    var status = getStatus(id: callbackToCancel)
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
        id: 9,
        failWithErr: nil
    )

    // Make sure the status is canceled
    status = getStatus(id: UInt64(9))
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

    // Check that no PendingExecution events were emitted yet (since callback is in the future)
    let pendingExecutionEventsBeforeTime = Test.eventsOfType(Type<FlowCallbackScheduler.PendingExecution>())
    Test.assert(pendingExecutionEventsBeforeTime.length == 0, message: "PendingExecution before time")

    var effort = getSlotAvailableEffort(timestamp: futureTime, priority: lowPriority)
    Test.assertEqual(UInt64(4000), effort!)

    // move time forward to trigger execution eligibility
    // Have to subtract to handle the automatic timestamp drift
    // so that the medium callback that got scheduled doesn't get marked as pendingExecution
    Test.moveTime(by: Fix64(futureDelta - 6.0))
    while getTimestamp() < futureTime {
        Test.moveTime(by: Fix64(1.0))
    }

    // Simulate FVM process - should process since timestamp is in the past
    processCallbacks()

    // Check for PendingExecution event after processing
    // Should have two high, one medium, and one low
    // and they should be in order
    // Cannot verify the order of events in tests at the moment
    // let expectedEventOrder: [UInt64] = [1, 4, 2, 5]

    let pendingExecutionEventsAfterTime = Test.eventsOfType(Type<FlowCallbackScheduler.PendingExecution>())
    Test.assertEqual(4, pendingExecutionEventsAfterTime.length)
    
    var i = 0
    var firstEvent: Bool = false
    for event in pendingExecutionEventsAfterTime {
        let pendingExecutionEvent = event as! FlowCallbackScheduler.PendingExecution
        Test.assert(
            pendingExecutionEvent.id != UInt64(3),
            message: "ID 3 Should not have been marked as pendingExecution"
        )

        // Cannot verify the order in tests at the moment
        // Test.assert(
        //     expectedEventOrder[i] == pendingExecutionEvent.id,
        //     message: "Events were not pendingExecution in priority order. Expected: \(expectedEventOrder[i]), got: \(pendingExecutionEvent.id)"
        // )

        // verify that the transactions got marked as pendingExecution
        var status = getStatus(id: pendingExecutionEvent.id)
        Test.assertEqual(statusExecuted, status)

        // Simulate FVM execute - should execute the callback
        if pendingExecutionEvent.id == callbackToFail {
            // ID 2 should fail, so need to verify that
            executeCallback(id: pendingExecutionEvent.id, failWithErr: "Callback \(callbackToFail) failed")
        } else {
            executeCallback(id: pendingExecutionEvent.id, failWithErr: nil)
        
            // Verify that the first event is the low priority callback
            if !firstEvent {
                let executedEvents = Test.eventsOfType(Type<FlowCallbackScheduler.Executed>())
                Test.assert(executedEvents.length == 1, message: "Should only have one Executed event")
                let executedEvent = executedEvents[0] as! FlowCallbackScheduler.Executed
                Test.assertEqual(pendingExecutionEvent.id, executedEvent.id)
                Test.assertEqual(pendingExecutionEvent.priority, executedEvent.priority)
                Test.assertEqual(pendingExecutionEvent.executionEffort, executedEvent.executionEffort)
                Test.assertEqual(pendingExecutionEvent.callbackOwner, executedEvent.callbackOwner)
                firstEvent = true
            }
        }

        i = i + 1
    }

    // Check for Executed events
    let executedEvents = Test.eventsOfType(Type<FlowCallbackScheduler.Executed>())
    Test.assert(executedEvents.length == 3, message: "Executed event wrong count")

    for event in executedEvents {
        let executedEvent = event as! FlowCallbackScheduler.Executed

        // Verify callback status is now Succeeded
        var status = getStatus(id: executedEvent.id)
        Test.assertEqual(statusExecuted, status)
    }

    // Check that the callbacks were executed
    var callbackIDs = executeScript(
        "./scripts/get_executed_callbacks.cdc",
        []
    ).returnValue! as! [UInt64]
    Test.assert(callbackIDs.length == 3, message: "Executed ids is the wrong count")


    // Verify failed callback status is still PendingExecution
    var status = getStatus(id: callbackToFail)
    Test.assertEqual(statusExecuted, status)

    // Move time forward by 5 so that
    // the other medium and low priority callbacks get marked as pendingExecution
    Test.moveTime(by: Fix64(5.0))

    // Process the two remaining callbacks
    processCallbacks()

    // Check that the failed callback is still marked as executed
    status = getStatus(id: callbackToFail)
    Test.assertEqual(statusExecuted, status)

    // Verify that the low priority callback for later is still scheduled
    status = getStatus(id: 7)
    Test.assertEqual(statusScheduled, status)

    // Execute the two remaining callbacks (medium and low)
    executeCallback(id: UInt64(3), failWithErr: nil)
    executeCallback(id: UInt64(6), failWithErr: nil)

    // Try to execute the low priority callback, should fail because it isn't pendingExecution
    executeCallback(
        id: 7,
        failWithErr: "Invalid ID: Cannot execute callback with id 7 because it has incorrect status \(statusScheduled)"
    )

    // Move time forward to after the low priority callback's requested timestamp
    Test.moveTime(by: Fix64(200.0))

    // Process the remaining callback
    processCallbacks()

    executeCallback(id: UInt64(7), failWithErr: nil)

    // Verify that the low priority callback is now executed
    status = getStatus(id: 7)
    Test.assertEqual(statusExecuted, status)    
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
        Test.assert(expectedError == estimate.error, message: "error mismatch for test case: \(testCase.name). Expected \(expectedError) but got \(estimate.error!)")
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
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: 1.1,
        canceledCallbacksLimit: nil,
        shouldFail: "Invalid refund multiplier: The multiplier must be between 0.0 and 1.0 but got 1.10000000"
    )

    setConfigDetails(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: {highPriority: 20.0, mediumPriority: 10.0, lowPriority: 0.9},
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        shouldFail: "Invalid priority fee multiplier: Low priority multiplier must be greater than or equal to 1.0 but got 0.90000000"
    )

    setConfigDetails(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: {highPriority: 20.0, mediumPriority: 3.0, lowPriority: 4.0},
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        shouldFail: "Invalid priority fee multiplier: Medium priority multiplier must be greater than or equal to 4.00000000 but got 3.00000000"
    )

    setConfigDetails(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: {highPriority: 5.0, mediumPriority: 6.0, lowPriority: 4.0},
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        shouldFail: "Invalid priority fee multiplier: High priority multiplier must be greater than or equal to 6.00000000 but got 5.00000000"
    )

    setConfigDetails(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: {highPriority: 40000, mediumPriority: 30000, lowPriority: 10000},
        priorityEffortLimit: {highPriority: 30000, mediumPriority: 30000, lowPriority: 10000},
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        shouldFail: "Invalid priority effort limit: High priority effort limit must be greater than or equal to the priority effort reserve of 40000"
    )

    setConfigDetails(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: {highPriority: 30000, mediumPriority: 40000, lowPriority: 10000},
        priorityEffortLimit: {highPriority: 30000, mediumPriority: 30000, lowPriority: 10000},
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        shouldFail: "Invalid priority effort limit: Medium priority effort limit must be greater than or equal to the priority effort reserve of 40000"
    )

    setConfigDetails(
        slotSharedEffortLimit: nil,
        priorityEffortReserve: {highPriority: 30000, mediumPriority: 30000, lowPriority: 20000},
        priorityEffortLimit: {highPriority: 30000, mediumPriority: 30000, lowPriority: 10000},
        minimumExecutionEffort: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        canceledCallbacksLimit: nil,
        shouldFail: "Invalid priority effort limit: Low priority effort limit must be greater than or equal to the priority effort reserve of 20000"
    )


    /** -------------
    Valid Test Case
    ---------------- */
    let oldConfig = getConfigDetails()
    Test.assertEqual(35000 as UInt64,oldConfig.slotTotalEffortLimit)
    Test.assertEqual(10000 as UInt64,oldConfig.slotSharedEffortLimit)
    Test.assertEqual(20000 as UInt64,oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.High]!)
    Test.assertEqual(5000 as UInt64,oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Medium]!)
    Test.assertEqual(0 as UInt64,oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Low]!)
    Test.assertEqual(30000 as UInt64,oldConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.High]!)
    Test.assertEqual(15000 as UInt64,oldConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Medium]!)
    Test.assertEqual(5000 as UInt64,oldConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Low]!)
    Test.assertEqual(10 as UInt64,oldConfig.minimumExecutionEffort)
    Test.assertEqual(10.0,oldConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.High]!)
    Test.assertEqual(5.0,oldConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Medium]!)
    Test.assertEqual(2.0,oldConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Low]!)
    Test.assertEqual(0.5,oldConfig.refundMultiplier)
    Test.assertEqual(720 as UInt,oldConfig.canceledCallbacksLimit) // 30 days with 1 per hour


    setConfigDetails(
        slotSharedEffortLimit: 20000,
        priorityEffortReserve: nil,
        priorityEffortLimit: {highPriority: 30000, mediumPriority: 30000, lowPriority: 10000},
        minimumExecutionEffort: 10,
        priorityFeeMultipliers: {highPriority: 20.0, mediumPriority: 10.0, lowPriority: 4.0},
        refundMultiplier: nil,
        canceledCallbacksLimit: 2000,
        shouldFail: nil
    )

    // Verify new config details
    let newConfig = getConfigDetails()
    Test.assertEqual(45000 as UInt64,newConfig.slotTotalEffortLimit)
    Test.assertEqual(20000 as UInt64,newConfig.slotSharedEffortLimit)
    Test.assertEqual(oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.High]!,newConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.High]!)
    Test.assertEqual(oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Medium]!,newConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Medium]!)
    Test.assertEqual(oldConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Low]!,newConfig.priorityEffortReserve[FlowCallbackScheduler.Priority.Low]!)
    Test.assertEqual(30000 as UInt64,newConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.High]!)
    Test.assertEqual(30000 as UInt64,newConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Medium]!)
    Test.assertEqual(10000 as UInt64,newConfig.priorityEffortLimit[FlowCallbackScheduler.Priority.Low]!)
    Test.assertEqual(10 as UInt64,newConfig.minimumExecutionEffort)
    Test.assertEqual(20.0,newConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.High]!)
    Test.assertEqual(10.0,newConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Medium]!)
    Test.assertEqual(4.0,newConfig.priorityFeeMultipliers[FlowCallbackScheduler.Priority.Low]!)
    Test.assertEqual(oldConfig.refundMultiplier,newConfig.refundMultiplier)
    Test.assertEqual(2000 as UInt,newConfig.canceledCallbacksLimit)
}

// Helper functions for scheduling a callback
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
        authorizers: [serviceAccount.address],
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
        authorizers: [serviceAccount.address],
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

// access(all) fun testPendingQueue() {
//     let testPendingQueueCode = Test.readFile("./transactions/test_pending_queue.cdc")
//     let testPendingQueueTx = Test.Transaction(
//         code: testPendingQueueCode,
//         authorizers: [serviceAccount.address],
//         signers: [serviceAccount],
//         arguments: [],
//     )

//     var result = Test.executeTransaction(testPendingQueueTx)
//     Test.expect(result, Test.beSucceeded())
// }

access(all) fun setConfigDetails(
    slotSharedEffortLimit: UInt64?,
    priorityEffortReserve: {UInt8: UInt64}?,
    priorityEffortLimit: {UInt8: UInt64}?,
    minimumExecutionEffort: UInt64?,
    priorityFeeMultipliers: {UInt8: UFix64}?,
    refundMultiplier: UFix64?,
    canceledCallbacksLimit: UInt?,
    shouldFail: String?
) {
    let setConfigDetailsCode = Test.readFile("../transactions/callbackScheduler/admin/set_config_details.cdc")
    let setConfigDetailsTx = Test.Transaction(
        code: setConfigDetailsCode,
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [slotSharedEffortLimit, priorityEffortReserve, priorityEffortLimit, minimumExecutionEffort, priorityFeeMultipliers, refundMultiplier, canceledCallbacksLimit]
    )
    let setConfigDetailsResult = Test.executeTransaction(setConfigDetailsTx)
    if let error = shouldFail {
        // log(error)
        // log(setConfigDetailsResult.error!.message)
        Test.expect(setConfigDetailsResult, Test.beFailed())
        // Check error
        Test.assertError(
            setConfigDetailsResult,
            errorMessage: error
        )
    } else {
        Test.expect(setConfigDetailsResult, Test.beSucceeded())
    }
}

access(all) fun getConfigDetails(): {FlowCallbackScheduler.SchedulerConfig} {
    var config = executeScript(
        "../transactions/callbackScheduler/scripts/get_config.cdc",
        []
    ).returnValue! as! {FlowCallbackScheduler.SchedulerConfig}
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
    return status
}

access(all) fun getSlotAvailableEffort(timestamp: UFix64, priority: UInt8): UInt64 {
    var result = executeScript(
        "../transactions/callbackScheduler/scripts/get_slot_available_effort.cdc",
        [timestamp, priority]
    )
    Test.expect(result, Test.beSucceeded())

    var effort = result.returnValue! as! UInt64
    return effort
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

// access(all) fun testPendingCallbackQueue() {
//     // Get current timestamp and set up future times
//     let currentTime = getCurrentBlock().timestamp
//     let futureTime1 = currentTime + 1000.0
//     let futureTime2 = currentTime + 2000.0
    
//     // Schedule callback 1 (high priority)
//     scheduleCallback(
//         timestamp: futureTime1,
//         fee: feeAmount,
//         effort: basicEffort,
//         priority: highPriority,
//         data: testData,
//         failWithErr: nil
//     )
    
//     // Schedule callback 2 (medium priority)
//     scheduleCallback(
//         timestamp: futureTime2,
//         fee: feeAmount,
//         effort: mediumEffort,
//         priority: mediumPriority,
//         data: testData,
//         failWithErr: nil
//     )
    
    
//     // Get the IDs of scheduled callbacks
//     let scheduledEvents = Test.eventsOfType(Type<FlowCallbackScheduler.Scheduled>())
//     let startIndex = scheduledEvents.length - 2
//     let callback1ID = (scheduledEvents[startIndex] as! FlowCallbackScheduler.Scheduled).id
//     let callback2ID = (scheduledEvents[startIndex + 1] as! FlowCallbackScheduler.Scheduled).id
    
//     // This test contract contains expected ID for each test we run, this is super awkward, 
//     // but because Test.Transaction doesn't allow arguments, we have to store them in a contract
//     let err = Test.deployContract(
//         name: "TestFlowCallbackQueue",
//         path: "../contracts/testContracts/TestFlowCallbackQueue.cdc",
//         arguments: [[
//             [], 
//             [callback1ID]
//         ] as [[UInt64]]]
//     )
//     Test.expect(err, Test.beNil())

//     testPendingQueue()

//     Test.moveTime(by: 1000.0)

//     testPendingQueue()

// }


