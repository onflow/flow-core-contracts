import Test
import BlockchainHelpers
import "FlowCallbackScheduler"
import "FlowToken"
import "TestFlowCallbackHandler"

import "callback_test_helpers.cdc"

access(all) let callbackToFail = 6 as UInt64
access(all) let callbackToCancel = 2 as UInt64

access(all) var startingHeight: UInt64 = 0

access(all) var feesBalanceBefore: UFix64 = 0.0
access(all) var accountBalanceBefore: UFix64 = 0.0

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

access(all) fun testCallbackScheduleEventAndData() {

    let currentTime = getTimestamp()
    let timeInFuture = currentTime + futureDelta

    accountBalanceBefore = getBalance(account: serviceAccount.address)
    feesBalanceBefore = getFeesBalance()
    
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
    Test.assertEqual("A.0000000000000001.TestFlowCallbackHandler.Handler", scheduledEvent.callbackHandlerTypeIdentifier!)
    Test.assertEqual("Test FlowCallbackHandler Resource", scheduledEvent.callbackName!)
    Test.assertEqual("Executes a variety of callbacks for different test cases", scheduledEvent.callbackDescription!)
    
    let callbackID = scheduledEvent.id as UInt64

    // Get scheduled callbacks from test callback handler
    let scheduledCallbacks = TestFlowCallbackHandler.scheduledCallbacks.keys
    Test.assert(scheduledCallbacks.length == 1, message: "one scheduled callback")
    
    let scheduled = TestFlowCallbackHandler.scheduledCallbacks[scheduledCallbacks[0]]!
    Test.assert(scheduled.id == callbackID, message: "callback ID mismatch")
    Test.assert(scheduled.timestamp == timeInFuture, message: "incorrect timestamp")

    var status = getStatus(id: callbackID)
    Test.assertEqual(statusScheduled, status!)

    var callbackData = getCallbackData(id: callbackID)
    Test.assertEqual(callbackID, callbackData!.id)
    Test.assertEqual(timeInFuture, callbackData!.scheduledTimestamp)
    Test.assertEqual(highPriority, callbackData!.priority.rawValue)
    Test.assertEqual(feeAmount, callbackData!.fees)
    Test.assertEqual(basicEffort, callbackData!.executionEffort)
    Test.assertEqual(statusScheduled, callbackData!.status.rawValue)
    Test.assertEqual("Test FlowCallbackHandler Resource", callbackData!.name)
    Test.assertEqual("Executes a variety of callbacks for different test cases", callbackData!.description)
    Test.assertEqual(serviceAccount.address, callbackData!.handlerAddress)
    Test.assertEqual("A.0000000000000001.TestFlowCallbackHandler.Handler", callbackData!.handlerTypeIdentifier)

    // invalid timeframe should return empty dictionary
    var callbacks = getCallbacksForTimeframe(startTimestamp: timeInFuture, endTimestamp: timeInFuture - 1.0)
    Test.assertEqual(0, callbacks.keys.length)

    callbacks = getCallbacksForTimeframe(startTimestamp: timeInFuture-10.0, endTimestamp: timeInFuture - 1.0)
    Test.assertEqual(0, callbacks.keys.length)

    callbacks = getCallbacksForTimeframe(startTimestamp: timeInFuture-10.0, endTimestamp: timeInFuture)
    Test.assertEqual(1, callbacks.keys.length)
    let callbacksAtFutureTime = callbacks[timeInFuture]!
    let highPriorityCallbacks = callbacksAtFutureTime[highPriority]!
    Test.assertEqual(1, highPriorityCallbacks.length)
    Test.assertEqual(callbackID, highPriorityCallbacks[0])

    // Try to execute the callback, should fail because it isn't pendingExecution
    executeCallback(
        id: callbackID,
        testName: "Test Callback Events Path: First High Scheduled",
        failWithErr: "Invalid ID: Cannot execute callback with id \(callbackID) because it has incorrect status \(statusScheduled)"
    )
}


access(all) fun testCallbackCancelationEvents() {

    var currentTime = getTimestamp()
    var timeInFuture = currentTime + futureDelta

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
    Test.assertEqual("A.0000000000000001.TestFlowCallbackHandler.Handler", canceledEvent.callbackHandlerTypeIdentifier!)
    Test.assertEqual("Test FlowCallbackHandler Resource", canceledEvent.callbackName!)
    Test.assertEqual("Executes a variety of callbacks for different test cases", canceledEvent.callbackDescription!)

    // Make sure the status is canceled
    var status = getStatus(id: callbackToCancel)
    Test.assertEqual(statusCanceled, status!)

    // Available Effort should be completely unused
    // for the slot that the canceled callback was in
    var effort = getSlotAvailableEffort(timestamp: timeInFuture, priority: mediumPriority)
    Test.assertEqual(UInt64(mediumPriorityMaxEffort), effort!)

    // Assert that the new balance reflects the refunds
    Test.assertEqual(balanceBefore - feeAmount/UFix64(2.0), getBalance(account: serviceAccount.address))
    Test.assertEqual(feesBalanceBefore + feeAmount/UFix64(2.0), getFeesBalance())
}

access(all) fun testCallbackExecution() {

    var currentTime = getTimestamp()
    var timeInFuture = currentTime + futureDelta

    feesBalanceBefore = getFeesBalance()

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

        // verify that the transactions got marked as executed
        var status = getStatus(id: pendingExecutionEvent.id)
        Test.assertEqual(statusExecuted, status!)

        // Simulate FVM execute - should execute the callback
        if pendingExecutionEvent.id == callbackToFail {
            // ID 2 should fail, so need to verify that
            executeCallback(id: pendingExecutionEvent.id, testName: "Test Callback Execution: First High Scheduled", failWithErr: "Callback \(callbackToFail) failed")
        } else {
            executeCallback(id: pendingExecutionEvent.id, testName: "Test Callback Execution: First High Scheduled", failWithErr: nil)
        
            // Verify that the first event is the high priority callback
            if !firstEvent {
                let executedEvents = Test.eventsOfType(Type<FlowCallbackScheduler.Executed>())
                Test.assert(executedEvents.length == 1, message: "Should only have one Executed event")
                let executedEvent = executedEvents[0] as! FlowCallbackScheduler.Executed
                Test.assertEqual(pendingExecutionEvent.id, executedEvent.id)
                Test.assertEqual(pendingExecutionEvent.priority, executedEvent.priority)
                Test.assertEqual(pendingExecutionEvent.executionEffort, executedEvent.executionEffort)
                Test.assertEqual(pendingExecutionEvent.callbackOwner, executedEvent.callbackOwner)
                Test.assertEqual(pendingExecutionEvent.callbackHandlerTypeIdentifier, executedEvent.callbackHandlerTypeIdentifier!)
                Test.assertEqual("Test FlowCallbackHandler Resource", executedEvent.callbackName!)
                Test.assertEqual("Executes a variety of callbacks for different test cases", executedEvent.callbackDescription!)
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
    
    Test.moveTime(by: Fix64(2.0))

    // Process callbacks again to remove the executed callbacks and pay fees
    processCallbacks()

    // Check that the fees were paid
    Test.assertEqual(feesBalanceBefore + feeAmount, getFeesBalance())

    // verify that the removed callback still counts as executed
    var status = getStatus(id: 1 as UInt64)
    Test.assertEqual(statusExecuted, status!)
}

access(all) fun testCallbackCancelationLimits() {

    // lower the canceled callbacks limit so the test runs faster
    setConfigDetails(
        maximumIndividualEffort: nil,
        slotSharedEffortLimit: nil,
        priorityEffortReserve: nil,
        priorityEffortLimit: nil,
        minimumExecutionEffort: nil,
        maxDataSizeMB: nil,
        priorityFeeMultipliers: nil,
        refundMultiplier: nil,
        canceledCallbacksLimit: 10,
        collectionEffortLimit: nil,
        collectionTransactionsLimit: nil,
        shouldFail: nil
    )

    let currentTime = getTimestamp()
    var timeInFuture = currentTime + futureDelta

    let numToCancel: UInt64 = 20
    var i: UInt64 = 0

    // Schedule numToCancel callbacks
    while i <= numToCancel {

        // Schedule a medium callback
        scheduleCallback(
            timestamp: timeInFuture + UFix64(i),
            fee: feeAmount,
            effort: mediumEffort,
            priority: mediumPriority,
            data: testData,
            testName: "Cancelation Limits: Scheduled \(i)",
            failWithErr: nil
        )

        i = i + 1

    }

    let startingID: UInt64 = 3
    var id = startingID

    while id < numToCancel + startingID {

        // Cancel the callbacks
        cancelCallback(
            id: id,
            failWithErr: nil
        )

        id = id + 1
    }

    // Check that the canceled callbacks are the ones we expect
    var canceledCallbacks = getCanceledCallbacks()
    Test.assertEqual(10, canceledCallbacks.length)

    // The first 12 canceled callbacks should have been removed from the canceled callbacks array
    i = 13 as UInt64
    for canceledID in canceledCallbacks {
        Test.assertEqual(i, canceledID)
        i = i + 1
    }

    // get the status of one of the first 30 callbacks and one of the later ones
    var status = getStatus(id: 1)
    Test.assertEqual(statusUnknown, status!)

    status = getStatus(id: 20)
    Test.assertEqual(statusCanceled, status!)
}

access(all) fun testCallbackScheduleAnotherCallback() {

    if startingHeight < getCurrentBlockHeight() {
        Test.reset(to: startingHeight)
    }

    let currentTime = getTimestamp()
    var timeInFuture = currentTime + futureDelta*5.0

    // Schedule a medium callback
    scheduleCallback(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: mediumEffort,
        priority: mediumPriority,
        data: "schedule",
        testName: "Schedule Another Callback: Scheduled",
        failWithErr: nil
    )

    let callbackData = getCallbackData(id: 1)
    Test.assertEqual(1 as UInt64,callbackData!.id)
    Test.assertEqual(timeInFuture, callbackData!.scheduledTimestamp)
    Test.assertEqual(mediumPriority, callbackData!.priority.rawValue)
    Test.assertEqual(feeAmount, callbackData!.fees)
    Test.assertEqual(mediumEffort, callbackData!.executionEffort)
    Test.assertEqual(statusScheduled, callbackData!.status.rawValue)

    Test.moveTime(by: Fix64(futureDelta*6.0))

    processCallbacks()

    executeCallback(
        id: 1,
        testName: "Schedule Another Callback: Executed",
        failWithErr: nil
    )

    // get the status of the newly scheduled callback with ID 2
    var status = getStatus(id: 2)
    Test.assertEqual(statusScheduled, status!)
    
}


access(all) fun testCallbackDestroyHandler() {

    if startingHeight < getCurrentBlockHeight() {
        Test.reset(to: startingHeight)
    }

    let currentTime = getTimestamp()
    var timeInFuture = currentTime + futureDelta*10.0

    // Schedule a medium callback
    scheduleCallback(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: mediumEffort,
        priority: mediumPriority,
        data: testData,
        testName: "Destroy Handler: Scheduled",
        failWithErr: nil
    )

    // Schedule a medium callback
    scheduleCallback(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: mediumEffort,
        priority: mediumPriority,
        data: testData,
        testName: "Destroy Handler: SecondScheduled To Cancel",
        failWithErr: nil
    )

    // Destroy the handler for both callbacks
    let executeCallbackCode = Test.readFile("./transactions/destroy_handler.cdc")
    let executeTx = Test.Transaction(
        code: executeCallbackCode,
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: []
    )
    var result = Test.executeTransaction(executeTx)
    Test.expect(result, Test.beSucceeded())

    // Cancel the second callback
    cancelCallback(
        id: 2,
        failWithErr: nil
    )
    
    // make sure the canceled event was emitted with empty handler values
    let canceledEvents = Test.eventsOfType(Type<FlowCallbackScheduler.Canceled>())
    Test.assertEqual(1, canceledEvents.length)
    let canceledEvent = canceledEvents[0] as! FlowCallbackScheduler.Canceled
    Test.assertEqual(UInt64(2), canceledEvent.id)
    Test.assertEqual(mediumPriority, canceledEvent.priority)
    Test.assertEqual(feeAmount/UFix64(2.0), canceledEvent.feesReturned)
    Test.assertEqual(feeAmount/UFix64(2.0), canceledEvent.feesDeducted)
    Test.assertEqual(Address(0x0000000000000001), canceledEvent.callbackOwner)
    Test.assertEqual("A.0000000000000001.TestFlowCallbackHandler.Handler", canceledEvent.callbackHandlerTypeIdentifier)
    Test.assertEqual("Test FlowCallbackHandler Resource", canceledEvent.callbackName)
    Test.assertEqual("Executes a variety of callbacks for different test cases", canceledEvent.callbackDescription)

    Test.moveTime(by: Fix64(futureDelta*11.0))

    processCallbacks()

    // The callback with the handler should not have emitted an event because the handler was destroyed
    let pendingExecutionEvents = Test.eventsOfType(Type<FlowCallbackScheduler.PendingExecution>())
    Test.assertEqual(0, pendingExecutionEvents.length)

    executeCallback(
        id: 1,
        testName: "Destroy Handler: Execute",
        failWithErr: "Invalid callback handler: Could not borrow a reference to the callback handler"
    )
    
}