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

access(all) let basicEffort: UInt64 = 1000
access(all) let mediumEffort: UInt64 = 10000
access(all) let heavyEffort: UInt64 = 20000

access(all) let testData = "test data"

access(all) let futureDelta = 100.0

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

access(all) fun testCallbackScheduling() {

    let currentTime = getCurrentBlock().timestamp
    let futureTime = currentTime + futureDelta
    let feeAmount = 10.0

    // Try to schedule callback with insufficient FLOW, should fail
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/callbackScheduler/schedule_callback.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [futureTime, 0.0, highPriority, testData],
    )
    var result = Test.executeTransaction(tx)
    Test.expect(result, Test.beFailed())
    
    // Setup handler and schedule callback using combined transaction with service account
    tx = Test.Transaction(
        code: Test.readFile("../transactions/callbackScheduler/schedule_callback.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [futureTime, feeAmount, basicEffort, highPriority, testData],
    )
    result = Test.executeTransaction(tx)
    Test.expect(result, Test.beSucceeded())

    // Check for CallbackScheduled event using Test.eventsOfType
    var scheduledEvents = Test.eventsOfType(Type<FlowCallbackScheduler.CallbackScheduled>())
    Test.assert(scheduledEvents.length == 1, message: "There should be one CallbackScheduled event")
    
    var scheduledEvent = scheduledEvents[0] as! FlowCallbackScheduler.CallbackScheduled
    Test.assertEqual(futureTime, scheduledEvent.timestamp!)
    Test.assert(scheduledEvent.executionEffort == 1000, message: "incorrect execution effort")
    Test.assertEqual(feeAmount, scheduledEvent.fees!)
    
    let callbackID = scheduledEvent.id

    // Get scheduled callbacks from test callback handler
    let scheduledCallbacks = TestFlowCallbackHandler.scheduledCallbacks 
    Test.assert(scheduledCallbacks.length == 1, message: "one scheduled callback")
    
    let scheduled = scheduledCallbacks[0]
    Test.assert(scheduled.id == callbackID, message: "callback ID mismatch")
    Test.assert(scheduled.timestamp == futureTime, message: "incorrect timestamp")

    var status = executeScript(
        "../transactions/callbackScheduler/scripts/get_status.cdc",
        [callbackID]
    ).returnValue! as! UInt8
    Test.assertEqual(UInt8(0), status!)

    // Schedule another callback, medium this time
    tx = Test.Transaction(
        code: Test.readFile("../transactions/callbackScheduler/schedule_callback.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [futureTime, feeAmount, mediumEffort, mediumPriority, testData],
    )
    result = Test.executeTransaction(tx)
    Test.expect(result, Test.beSucceeded())

    // Schedule another medium callback but it should be put in a future timestamp
    // because it doesn't fit in the requested timestamp
    tx = Test.Transaction(
        code: Test.readFile("../transactions/callbackScheduler/schedule_callback.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [futureTime, feeAmount, mediumEffort, mediumPriority, testData],
    )
    result = Test.executeTransaction(tx)
    Test.expect(result, Test.beSucceeded())

    // verify that the main timestamp still has 5000 left for medium
    var effort = executeScript(
        "../transactions/callbackScheduler/scripts/get_slot_available_effort.cdc",
        [futureTime, mediumPriority]
    ).returnValue! as! UInt64
    Test.assertEqual(UInt64(5000), effort!)

    // verify that the next timestamp has 5000 left after the callback that was moved
    effort = executeScript(
        "../transactions/callbackScheduler/scripts/get_slot_available_effort.cdc",
        [futureTime + 1.0, mediumPriority]
    ).returnValue! as! UInt64
    Test.assertEqual(UInt64(5000), effort!)

    // Schedule another high callback which should fit
    tx = Test.Transaction(
        code: Test.readFile("../transactions/callbackScheduler/schedule_callback.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [futureTime, feeAmount, heavyEffort, highPriority, testData],
    )
    result = Test.executeTransaction(tx)
    Test.expect(result, Test.beSucceeded())

    effort = executeScript(
        "../transactions/callbackScheduler/scripts/get_slot_available_effort.cdc",
        [futureTime, highPriority]
    ).returnValue! as! UInt64
    Test.assertEqual(UInt64(4000), effort!)

    // Try to schedule another high callback which should fail because it doesn't
    // fit into the requested timestamp
    tx = Test.Transaction(
        code: Test.readFile("../transactions/callbackScheduler/schedule_callback.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [futureTime, feeAmount, heavyEffort, highPriority, testData],
    )
    result = Test.executeTransaction(tx)
    Test.expect(result, Test.beFailed())

    // Schedule a low callback
    tx = Test.Transaction(
        code: Test.readFile("../transactions/callbackScheduler/schedule_callback.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [futureTime, feeAmount, basicEffort, lowPriority, testData],
    )
    result = Test.executeTransaction(tx)
    Test.expect(result, Test.beSucceeded())

    effort = executeScript(
        "../transactions/callbackScheduler/scripts/get_slot_available_effort.cdc",
        [futureTime, lowPriority]
    ).returnValue! as! UInt64
    Test.assertEqual(UInt64(4000), effort!)

}

access(all) fun testCallbackExecution() {

    var scheduledCallbacks = TestFlowCallbackHandler.scheduledCallbacks
    var ids: [UInt64] = []
    for callback in scheduledCallbacks {
        ids.append(callback.id)
    }

    // Simulate FVM process - should not yet process since timestamp is in the future
    let processCallbackCode = Test.readFile("./transactions/process_callback.cdc")
    var processTx = Test.Transaction(
        code: processCallbackCode,
        authorizers: [],
        signers: [serviceAccount],
        arguments: []
    )
    Test.expect(Test.executeTransaction(processTx), Test.beSucceeded())

    // Check that no CallbackProcessed events were emitted yet (since callback is in the future)
    let processedEventsBeforeTime = Test.eventsOfType(Type<FlowCallbackScheduler.CallbackProcessed>())
    Test.assert(processedEventsBeforeTime.length == 0, message: "CallbackProcessed before time")

    // move time forward to trigger execution eligibility
    Test.moveTime(by: Fix64(futureDelta + 1.0))

    // Simulate FVM process - should process since timestamp is in the past
    processTx = Test.Transaction(
        code: processCallbackCode,
        authorizers: [],
        signers: [serviceAccount],
        arguments: []
    )
    Test.expect(Test.executeTransaction(processTx), Test.beSucceeded())

    // Check for CallbackProcessed event after processing
    let processedEventsAfterTime = Test.eventsOfType(Type<FlowCallbackScheduler.CallbackProcessed>())
    Test.assertEqual(4, processedEventsAfterTime.length)
    
    let processedEvent = processedEventsAfterTime[0] as! FlowCallbackScheduler.CallbackProcessed
    for id in ids {
        if id == processedEvent.id {
            Test.assert(processedEvent.executionEffort == 1000, message: "execution effort mismatch")
        }
    }

    var status = executeScript(
        "../transactions/callbackScheduler/scripts/get_status.cdc",
        [ids[0]]
    ).returnValue! as! UInt8
    Test.assertEqual(UInt8(1), status!)

    // Simulate FVM execute - should execute the callback
    let executeCallbackCode = Test.readFile("./transactions/execute_callback.cdc")
    let executeTx = Test.Transaction(
        code: executeCallbackCode,
        authorizers: [],
        signers: [serviceAccount],
        arguments: [ids[0]]
    )
    Test.expect(Test.executeTransaction(executeTx), Test.beSucceeded())
    
    // Check for CallbackExecuted event
    let executedEvents = Test.eventsOfType(Type<FlowCallbackScheduler.CallbackExecuted>())
    Test.assert(executedEvents.length == 1, message: "CallbackExecuted event wrong count")
    
    let executedEvent = executedEvents[0] as! FlowCallbackScheduler.CallbackExecuted
    Test.assert(executedEvent.id == ids[0], message: "callback ID mismatch")
    
    // Verify callback status is now Executed
    status = executeScript(
        "../transactions/callbackScheduler/scripts/get_status.cdc",
        [ids[0]]
    ).returnValue! as! UInt8
    Test.assertEqual(UInt8(2), status!)

    // Check that the callback was executed
    var callbackIDs = executeScript(
        "./scripts/get_executed_callbacks.cdc",
        []
    ).returnValue! as! [UInt64]
    Test.assert(callbackIDs[0] == ids[0], message: "callback ID mismatch")
}


/*
TODO test cases:
- test schedule and then cancel and make sure it is canceled and we can get the status after being canceled
- schedule multiple callbacks at different times and make sure they are correctly executed 
- test filling all slot room with high and medium priority and make sure the ones that are scheduled are exceuted
- test filling all slot room with high and medium and see that low priority only gets executed after high and medium are
- test filling all slot room with high and medimum and then add more medium priority which should be executed in next available slot
 */


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
