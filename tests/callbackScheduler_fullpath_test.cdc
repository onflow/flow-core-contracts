import Test
import BlockchainHelpers
import "FlowCallbackScheduler"
import "FlowToken"
import "TestFlowCallbackHandler"

import "test_helpers.cdc"

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

access(all) let highPriorityEffortReserve: UInt64 = 20000
access(all) let mediumPriorityEffortReserve: UInt64 = 5000
access(all) let sharedEffortLimit: UInt64 = 10000

access(all) let testData = "test data"
access(all) let failTestData = "fail"

access(all) let callbackToFail = 2 as UInt64
access(all) let callbackToCancel = 8 as UInt64

access(all) let futureDelta = 1000.0
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

    startingHeight = getCurrentBlockHeight()
}

/** ---------------------------------------------------------------------------------
 Callback handler integration tests
 --------------------------------------------------------------------------------- */

access(all) fun testCallbackScheduling() {

    if startingHeight < getCurrentBlockHeight() {
        Test.reset(to: startingHeight)
    }

    let currentTime = getTimestamp()
    futureTime = currentTime + futureDelta*10.0

    log("Current time: \(currentTime)")
    log("Future time: \(futureTime)")
    log("Get Timestamp: \(getTimestamp())")
    log("Test framework timestamp: \(getCurrentBlock().timestamp)")

    // Try to schedule callback with insufficient FLOW, should fail
    scheduleCallback(
        timestamp: futureTime,
        fee: 0.0,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        testName: "Test Callback Scheduling: First High Scheduled Fails because of insufficient fees",
        failWithErr: "Insufficient fees: The Fee balance of 0.00000000 is not sufficient to pay the required amount of 0.00010000 for execution of the callback."
    )
    
    // Schedule high priority callback
    scheduleCallback(
        timestamp: futureTime,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        data: testData,
        testName: "Test Callback Scheduling: First High Scheduled",
        failWithErr: nil
    )

    // Check for Scheduled event using Test.eventsOfType
    var scheduledEvents = Test.eventsOfType(Type<FlowCallbackScheduler.Scheduled>())
    Test.assert(scheduledEvents.length == 1, message: "There should be one Scheduled event but there are \(scheduledEvents.length) events")
    
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
        testName: "Test Callback Scheduling: First Medium Scheduled",
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
        testName: "Test Callback Scheduling: Second Medium Scheduled",
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
        testName: "Test Callback Scheduling: SecondHigh Priority Callback",
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
        testName: "Test Callback Scheduling: High Priority Callback Fails because of existing high priority callback",
        failWithErr: "Invalid execution effort: \(heavyEffort) is greater than the priority's available effort for the requested timestamp."
    )

    // Schedule a low callback that is expected to fit in the `futureTime` slot
    scheduleCallback(
        timestamp: futureTime,
        fee: feeAmount,
        effort: basicEffort,
        priority: lowPriority,
        data: testData,
        testName: "Test Callback Scheduling: First Low Scheduled",
        failWithErr: nil
    )

    // Make sure the low priority status and available effort
    // for the `futureTime` slot is correct
    status = getStatus(id: UInt64(5))
    Test.assertEqual(statusScheduled, status)

    effort = getSlotAvailableEffort(timestamp: futureTime, priority: lowPriority)
    Test.assertEqual(UInt64(3000), effort!)

    // Schedule a low callback that has an effort of 5000
    // so it will not fit in the `futureTime` slot but will still get scheduled
    scheduleCallback(
        timestamp: futureTime,
        fee: feeAmount,
        effort: lowPriorityMaxEffort,
        priority: lowPriority,
        data: testData,
        testName: "Test Callback Scheduling: Second toLast Low Scheduled",
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
        testName: "Test Callback Scheduling: Last Low Scheduled",
        failWithErr: nil
    )

    // Make sure the low priority status and available effort
    // for the `futureTime` slot is correct
    status = getStatus(id: UInt64(6))
    Test.assertEqual(statusScheduled, status)

    effort = getSlotAvailableEffort(timestamp: futureTime, priority: lowPriority)
    Test.assertEqual(UInt64(3000), effort!)

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
        testName: "Test Callback Cancelation: First Scheduled",
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
        testName: "Test Callback Cancelation: Second Scheduled",
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

    // move time forward to trigger execution eligibility
    // Have to subtract to handle the automatic timestamp drift
    // so that the medium callback that got scheduled doesn't get marked as pendingExecution
    Test.moveTime(by: Fix64(futureDelta*10.0 - 6.0))
    while getTimestamp() < futureTime {
        Test.moveTime(by: Fix64(1.0))
    }

    // Simulate FVM process - should process since timestamp is in the past
    processCallbacks()

    // Check for PendingExecution event after processing
    // Should have two high, one medium, and one low

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