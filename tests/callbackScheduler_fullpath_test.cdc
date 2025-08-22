import Test
import BlockchainHelpers
import "FlowCallbackScheduler"
import "FlowToken"
import "TestFlowCallbackHandler"

import "test_helpers.cdc"

access(all) let callbackToFail = 6 as UInt64
access(all) let callbackToCancel = 2 as UInt64

access(all)var timeInFuture: UFix64 = 0.0

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

access(all) fun testCallbackEventsPath() {

    let currentTime = getTimestamp()
    timeInFuture = currentTime + futureDelta
    
    // Schedule high priority callback
    scheduleCallback(
        timestamp: timeInFuture,
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
    Test.assertEqual(timeInFuture, scheduledEvent.timestamp!)
    Test.assert(scheduledEvent.executionEffort == 1000, message: "incorrect execution effort")
    Test.assertEqual(feeAmount, scheduledEvent.fees!)
    Test.assertEqual(serviceAccount.address, scheduledEvent.callbackOwner!)
    
    let callbackID = scheduledEvent.id as UInt64

    // Get scheduled callbacks from test callback handler
    let scheduledCallbacks = TestFlowCallbackHandler.scheduledCallbacks.keys
    Test.assert(scheduledCallbacks.length == 1, message: "one scheduled callback")
    
    let scheduled = TestFlowCallbackHandler.scheduledCallbacks[scheduledCallbacks[0]]!
    Test.assert(scheduled.id == callbackID, message: "callback ID mismatch")
    Test.assert(scheduled.timestamp == timeInFuture, message: "incorrect timestamp")

    var status = getStatus(id: callbackID)
    Test.assertEqual(statusScheduled, status)

    // Try to execute the callback, should fail because it isn't pendingExecution
    executeCallback(
        id: callbackID,
        failWithErr: "Invalid ID: Cannot execute callback with id \(callbackID) because it has incorrect status \(statusScheduled)"
    )
}


access(all) fun testCallbackCancelationEvents() {

    var currentTime = getTimestamp()
    timeInFuture = currentTime + futureDelta

    var balanceBefore = getBalance(account: serviceAccount.address)

    // Cancel invalid callback should fail
    cancelCallback(
        id: 100,
        failWithErr: "Invalid ID: 100 callback not found"
    )

    // Schedule a medium callback
    scheduleCallback(
        timestamp: timeInFuture,
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
    var effort = getSlotAvailableEffort(timestamp: timeInFuture, priority: mediumPriority)
    Test.assertEqual(UInt64(mediumPriorityMaxEffort), effort!)

    // Assert that the new balance reflects the refunds
    Test.assertEqual(balanceBefore - feeAmount/UFix64(2.0), getBalance(account: serviceAccount.address))
    
}

access(all) fun testCallbackExecution() {

    var currentTime = getTimestamp()
    timeInFuture = currentTime + futureDelta

    var scheduledIDs = TestFlowCallbackHandler.scheduledCallbacks.keys

    // Simulate FVM process - should not yet process since timestamp is in the future
    processCallbacks()

    // Check that no PendingExecution events were emitted yet (since callback is in the future)
    let pendingExecutionEventsBeforeTime = Test.eventsOfType(Type<FlowCallbackScheduler.PendingExecution>())
    Test.assert(pendingExecutionEventsBeforeTime.length == 0, message: "PendingExecution before time")

    // move time forward to trigger execution eligibility
    // Have to subtract to handle the automatic timestamp drift
    // so that the medium callback that got scheduled doesn't get marked as pendingExecution
    Test.moveTime(by: Fix64(futureDelta - 6.0))
    while getTimestamp() < timeInFuture {
        Test.moveTime(by: Fix64(1.0))
    }

    // Simulate FVM process - should process since timestamp is in the past
    processCallbacks()

    // Check for PendingExecution event after processing
    // Should have one high

    let pendingExecutionEventsAfterTime = Test.eventsOfType(Type<FlowCallbackScheduler.PendingExecution>())
    Test.assertEqual(1, pendingExecutionEventsAfterTime.length)
    
    var i = 0
    var firstEvent: Bool = false
    for event in pendingExecutionEventsAfterTime {
        let pendingExecutionEvent = event as! FlowCallbackScheduler.PendingExecution
        Test.assert(
            pendingExecutionEvent.id != UInt64(2),
            message: "ID 2 Should not have been marked as pendingExecution"
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
        
            // Verify that the first event is the high priority callback
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

    // Check that the callbacks were executed
    var callbackIDs = _executeScript(
        "./scripts/get_executed_callbacks.cdc",
        []
    ).returnValue! as! [UInt64]
    Test.assert(callbackIDs.length == 1, message: "Executed ids is the wrong count")


    // TODO: Test Failed Callbacks
    //Verify failed callback status is still PendingExecution
    // var status = getStatus(id: callbackToFail)
    // Test.assertEqual(statusExecuted, status)

    // // Check that the failed callback is still marked as executed
    // status = getStatus(id: callbackToFail)
    // Test.assertEqual(statusExecuted, status)



    // // Try to execute the low priority callback, should fail because it isn't pendingExecution
    // executeCallback(
    //     id: 7,
    //     failWithErr: "Invalid ID: Cannot execute callback with id 7 because it has incorrect status \(statusScheduled)"
    // )

    // // Move time forward to after the low priority callback's requested timestamp
    // Test.moveTime(by: Fix64(200.0))

    // // Process the remaining callback
    // processCallbacks()

    // executeCallback(id: UInt64(7), failWithErr: nil)

    // // Verify that the low priority callback is now executed
    // status = getStatus(id: 7)
    // Test.assertEqual(statusExecuted, status)    
}