import Test
import "CallbackScheduler"
import "FlowToken"

// Account 7 is where new contracts are deployed by default
access(all) let admin = Test.getAccount(0x0000000000000007)

access(all)
fun setup() {
    let err = Test.deployContract(
        name: "CallbackScheduler",
        path: "../contracts/CallbackScheduler.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}


/** ---------------------------------------------------------------------------------
 Callback scheduler estimate() tests
 --------------------------------------------------------------------------------- */

// Test case structure for estimate function
access(all) struct EstimateTestCase {
    access(all) let name: String
    access(all) let timestamp: UFix64
    access(all) let priority: CallbackScheduler.Priority
    access(all) let executionEffort: UInt64
    access(all) let data: AnyStruct?
    access(all) let expectNil: Bool
    access(all) let expectedFee: UFix64?
    access(all) let expectedTimestamp: UFix64?
    access(all) let expectedError: String?

    access(all) init(
        name: String,
        timestamp: UFix64,
        priority: CallbackScheduler.Priority,
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
            priority: CallbackScheduler.Priority.Low,
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
            priority: CallbackScheduler.Priority.High,
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
            priority: CallbackScheduler.Priority.Medium,
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
            priority: CallbackScheduler.Priority.High,
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
            priority: CallbackScheduler.Priority.High,
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
            priority: CallbackScheduler.Priority.Medium,
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
            priority: CallbackScheduler.Priority.High,
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
            priority: CallbackScheduler.Priority.Medium,
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
            priority: CallbackScheduler.Priority.High,
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
            priority: CallbackScheduler.Priority.High,
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
            priority: CallbackScheduler.Priority.Medium,
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
    let result = CallbackScheduler.estimate(
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
