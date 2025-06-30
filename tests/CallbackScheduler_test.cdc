import Test
import "FlowCallbackScheduler"
import "FlowToken"
import "TestFlowCallbackHandler"

// Account 7 is where new contracts are deployed by default
access(all) let admin = Test.getAccount(0x0000000000000007)

access(all)
fun setup() {
    let err = Test.deployContract(
        name: "FlowCallbackScheduler",
        path: "../contracts/FlowCallbackScheduler.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    let handlerErr = Test.deployContract(
        name: "TestFlowCallbackHandler",
        path: "../contracts/testContracts/TestFlowCallbackHandler.cdc",
        arguments: []
    )
    Test.expect(handlerErr, Test.beNil())
}

/** ---------------------------------------------------------------------------------
 Callback handler integration tests
 --------------------------------------------------------------------------------- */

access(all) fun testCallbackSchedulingAndExecution() {
    let serviceAccount = Test.serviceAccount()
    let currentTime = getCurrentBlock().timestamp
    let futureDelta = 100.0
    let futureTime = currentTime + futureDelta
    let testData = "test data"
    let feeAmount = 10.0
    let highPriority = UInt8(2)
    
    // Setup handler and schedule callback using combined transaction with service account
    let tx = Test.Transaction(
        code: Test.readFile("./transactions/schedule_callback.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [futureTime, feeAmount, highPriority, testData],
    )
    let result = Test.executeTransaction(tx)
    Test.expect(result, Test.beSucceeded())

    // Check for CallbackScheduled event using Test.eventsOfType
    let scheduledEvents = Test.eventsOfType(Type<FlowCallbackScheduler.CallbackScheduled>())
    Test.assert(scheduledEvents.length == 1, message: "one CallbackScheduled event")
    
    let scheduledEvent = scheduledEvents[0] as! FlowCallbackScheduler.CallbackScheduled
    Test.assert(scheduledEvent.timestamp == futureTime, message: "incorrect timestamp")
    Test.assert(scheduledEvent.executionEffort == 1000, message: "incorrect execution effort")
    
    let callbackID = scheduledEvent.id

    // Get scheduled callbacks from test callback handler
    let scheduledCallbacks = TestFlowCallbackHandler.scheduledCallbacks 
    Test.assert(scheduledCallbacks.length == 1, message: "one scheduled callback")
    
    let scheduled = scheduledCallbacks[0]
    Test.assert(scheduled.id == callbackID, message: "callback ID mismatch")
    Test.assert(scheduled.timestamp == futureTime, message: "incorrect timestamp")
    Test.assert(scheduled.status() == FlowCallbackScheduler.Status.Scheduled, message: "incorrect status")

    var status = FlowCallbackScheduler.getStatus(id: callbackID)
    Test.assertEqual(FlowCallbackScheduler.Status.Scheduled, status!)

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
    Test.assert(processedEventsAfterTime.length == 1, message: "CallbackProcessed event wrong count")
    
    let processedEvent = processedEventsAfterTime[0] as! FlowCallbackScheduler.CallbackProcessed
    Test.assert(processedEvent.id == callbackID, message: "callback ID mismatch")
    Test.assert(processedEvent.executionEffort == 1000, message: "execution effort mismatch")


    // status = CallbackScheduler.getStatus(ID: callbackID)
    // Test.assertEqual(CallbackScheduler.Status.Processed, status!)

    // Simulate FVM execute - should execute the callback
    let executeCallbackCode = Test.readFile("./transactions/execute_callback.cdc")
    let executeTx = Test.Transaction(
        code: executeCallbackCode,
        authorizers: [],
        signers: [serviceAccount],
        arguments: [callbackID]
    )
    Test.expect(Test.executeTransaction(executeTx), Test.beSucceeded())
    
    // Check for CallbackExecuted event
    let executedEvents = Test.eventsOfType(Type<FlowCallbackScheduler.CallbackExecuted>())
    Test.assert(executedEvents.length == 1, message: "CallbackExecuted event wrong count")
    
    let executedEvent = executedEvents[0] as! FlowCallbackScheduler.CallbackExecuted
    Test.assert(executedEvent.id == callbackID, message: "callback ID mismatch")
    
    // TODO: Verify callback status is now Executed - this is not working as expected right now, the status is not updated
    // status = FlowCallbackScheduler.getStatus(id: callbackID)
    //Test.assertEqual(FlowCallbackScheduler.Status.Executed, status!)
    // Check that the callback was executed
    //let executedCallback = TestFlowCallbackHandler.executedCallback
    //Test.assert(executedCallback == callbackID, message: "callback ID mismatch")
}


/*
TODO test cases:
- fix above schedule test to correctly track status updates and make sure we can query status after execution
- test schedule and then cancel and make sure it is canceled and we can get the status after being canceled
- schedule multiple callbacks at different times and make sure they are correctly executed 
- test filling all slot room with high and medium priority and make sure the ones that are scheduled are exceuted
- test filling all slot room with high and medimum and see that low priority only gets executed after high and medium are
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
    access(all) let expectNil: Bool
    access(all) let expectedFee: UFix64?
    access(all) let expectedTimestamp: UFix64?
    access(all) let expectedError: String?

    access(all) init(
        name: String,
        timestamp: UFix64,
        priority: FlowCallbackScheduler.Priority,
        executionEffort: UInt64,
        data: AnyStruct?,
        expectNil: Bool,
        expectedFee: UFix64?,
        expectedTimestamp: UFix64?,
        expectedError: String?
    ) {
        self.name = name
        self.timestamp = timestamp
        self.priority = priority
        self.executionEffort = executionEffort
        self.data = data
        self.expectNil = expectNil
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
            name: "Low priority returns error",
            timestamp: futureTime,
            priority: FlowCallbackScheduler.Priority.Low,
            executionEffort: 1000,
            data: nil,
            expectNil: false,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid priority: low priority callbacks estimation not supported"
        ),
        EstimateTestCase(
            name: "Past timestamp returns error",
            timestamp: pastTime,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 1000,
            data: nil,
            expectNil: false,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid timestamp: timestamp is in the past"
        ),
        EstimateTestCase(
            name: "Current timestamp returns error",
            timestamp: currentTime,
            priority: FlowCallbackScheduler.Priority.Medium,
            executionEffort: 1000,
            data: nil,
            expectNil: false,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid timestamp: timestamp is in the past"
        ),
        EstimateTestCase(
            name: "Zero execution effort returns error",
            timestamp: futureTime + 7.0,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 0,
            data: nil,
            expectNil: false,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid execution effort: less than minimum execution effort"
        ),
        EstimateTestCase(
            name: "Excessive high priority effort returns error",
            timestamp: futureTime + 8.0,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 50000,
            data: nil,
            expectNil: false,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid execution effort: greater than available effort for priority"
        ),
        EstimateTestCase(
            name: "Excessive medium priority effort returns error",
            timestamp: futureTime + 9.0,
            priority: FlowCallbackScheduler.Priority.Medium,
            executionEffort: 20000,
            data: nil,
            expectNil: false,
            expectedFee: nil,
            expectedTimestamp: nil,
            expectedError: "Invalid execution effort: greater than available effort for priority"
        ),

        // Valid cases - should return EstimatedCallback with no error
        EstimateTestCase(
            name: "High priority effort",
            timestamp: futureTime + 1.0,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 5000,
            data: nil,
            expectNil: false,
            expectedFee: 5.0,
            expectedTimestamp: futureTime + 1.0,
            expectedError: nil
        ),
        EstimateTestCase(
            name: "Medium priority minimum effort",
            timestamp: futureTime + 4.0,
            priority: FlowCallbackScheduler.Priority.Medium,
            executionEffort: 5,
            data: nil,
            expectNil: false,
            expectedFee: 0.0025,
            expectedTimestamp: futureTime + 4.0,
            expectedError: nil
        ),
        EstimateTestCase(
            name: "Far future timestamp",
            timestamp: farFutureTime,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 1000,
            data: nil,
            expectNil: false,
            expectedFee: 1.0,
            expectedTimestamp: farFutureTime,
            expectedError: nil
        ),
        EstimateTestCase(
            name: "String data",
            timestamp: futureTime + 10.0,
            priority: FlowCallbackScheduler.Priority.High,
            executionEffort: 1000,
            data: "string data",
            expectNil: false,
            expectedFee: 1.0,
            expectedTimestamp: futureTime + 10.0,
            expectedError: nil
        ),
        EstimateTestCase(
            name: "Dictionary data",
            timestamp: futureTime + 11.0,
            priority: FlowCallbackScheduler.Priority.Medium,
            executionEffort: 1000,
            data: {"key": "value"},
            expectNil: false,
            expectedFee: 0.5,
            expectedTimestamp: futureTime + 11.0,
            expectedError: nil
        )
    ]

    for testCase in estimateTestCases {
        runEstimateTestCase(testCase: testCase)
    }
}

access(all) fun runEstimateTestCase(testCase: EstimateTestCase) {
    let result = FlowCallbackScheduler.estimate(
        data: testCase.data,
        timestamp: testCase.timestamp,
        priority: testCase.priority,
        executionEffort: testCase.executionEffort
    )
    
    if testCase.expectNil {
        Test.assert(result == nil, message: "expected nil for test case: ".concat(testCase.name))
    } else {
        Test.assert(result != nil, message: "expected non-nil for test case: ".concat(testCase.name))
        
        if let estimate = result {
            // Check fee
            if let expectedFee = testCase.expectedFee {
                Test.assert(expectedFee == estimate.flowFee, message: "fee mismatch for test case: ".concat(testCase.name))
            } else {
                Test.assert(estimate.flowFee == nil, message: "expected nil fee for test case: ".concat(testCase.name))
            }
            
            // Check timestamp
            if let expectedTimestamp = testCase.expectedTimestamp {
                Test.assert(expectedTimestamp == estimate.timestamp, message: "timestamp mismatch for test case: ".concat(testCase.name))
            } else {
                Test.assert(estimate.timestamp == nil, message: "expected nil timestamp for test case: ".concat(testCase.name))
            }
            
            // Check error
            if let expectedError = testCase.expectedError {
                Test.assert(expectedError == estimate.error, message: "error mismatch for test case: ".concat(testCase.name))
            } else {
                Test.assert(estimate.error == nil, message: "expected nil error for test case: ".concat(testCase.name))
            }
        }
    }
}
