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

    access(all) init(
        name: String,
        timestamp: UFix64,
        priority: CallbackScheduler.Priority,
        executionEffort: UInt64,
        data: AnyStruct?,
        expectNil: Bool,
        expectedFee: UFix64?,
        expectedTimestamp: UFix64?
    ) {
        self.name = name
        self.timestamp = timestamp
        self.priority = priority
        self.executionEffort = executionEffort
        self.data = data
        self.expectNil = expectNil
        self.expectedFee = expectedFee
        self.expectedTimestamp = expectedTimestamp
    }
}

access(all) fun testEstimate() {
    let currentTime = getCurrentBlock().timestamp
    let futureTime = currentTime + 100.0
    let pastTime = currentTime - 100.0
    let farFutureTime = currentTime + 10000.0

    let estimateTestCases: [EstimateTestCase] = [
        // Nil cases
        EstimateTestCase(
            name: "Low priority returns nil",
            timestamp: futureTime,
            priority: CallbackScheduler.Priority.Low,
            executionEffort: 1000,
            data: nil,
            expectNil: true,
            expectedFee: nil,
            expectedTimestamp: nil
        ),
        EstimateTestCase(
            name: "Past timestamp returns nil",
            timestamp: pastTime,
            priority: CallbackScheduler.Priority.High,
            executionEffort: 1000,
            data: nil,
            expectNil: true,
            expectedFee: nil,
            expectedTimestamp: nil
        ),
        EstimateTestCase(
            name: "Current timestamp returns nil",
            timestamp: currentTime,
            priority: CallbackScheduler.Priority.Medium,
            executionEffort: 1000,
            data: nil,
            expectNil: true,
            expectedFee: nil,
            expectedTimestamp: nil
        ),

        // Valid high priority cases
        EstimateTestCase(
            name: "High priority minimum effort",
            timestamp: futureTime + 1.0,
            priority: CallbackScheduler.Priority.High,
            executionEffort: 5,
            data: nil,
            expectNil: false,
            expectedFee: 0.005,
            expectedTimestamp: futureTime + 1.0
        ),
        EstimateTestCase(
            name: "High priority normal effort",
            timestamp: futureTime + 2.0,
            priority: CallbackScheduler.Priority.High,
            executionEffort: 1000,
            data: nil,
            expectNil: false,
            expectedFee: 1.0,
            expectedTimestamp: futureTime + 2.0
        ),
        EstimateTestCase(
            name: "High priority maximum effort",
            timestamp: futureTime + 3.0,
            priority: CallbackScheduler.Priority.High,
            executionEffort: 30000,
            data: nil,
            expectNil: false,
            expectedFee: 30.0,
            expectedTimestamp: futureTime + 3.0
        ),

        // Valid medium priority cases
        EstimateTestCase(
            name: "Medium priority minimum effort",
            timestamp: futureTime + 4.0,
            priority: CallbackScheduler.Priority.Medium,
            executionEffort: 5,
            data: nil,
            expectNil: false,
            expectedFee: 0.0025,
            expectedTimestamp: futureTime + 4.0
        ),
        EstimateTestCase(
            name: "Medium priority normal effort",
            timestamp: futureTime + 5.0,
            priority: CallbackScheduler.Priority.Medium,
            executionEffort: 1000,
            data: nil,
            expectNil: false,
            expectedFee: 0.5,
            expectedTimestamp: futureTime + 5.0
        ),
        EstimateTestCase(
            name: "Medium priority maximum effort",
            timestamp: futureTime + 6.0,
            priority: CallbackScheduler.Priority.Medium,
            executionEffort: 15000,
            data: nil,
            expectNil: false,
            expectedFee: 7.5,
            expectedTimestamp: futureTime + 6.0
        ),

        // Edge cases
        EstimateTestCase(
            name: "Zero execution effort",
            timestamp: futureTime + 7.0,
            priority: CallbackScheduler.Priority.High,
            executionEffort: 0,
            data: nil,
            expectNil: true,
            expectedFee: nil,
            expectedTimestamp: nil
        ),
        EstimateTestCase(
            name: "Far future timestamp",
            timestamp: farFutureTime,
            priority: CallbackScheduler.Priority.High,
            executionEffort: 1000,
            data: nil,
            expectNil: false,
            expectedFee: 1.0,
            expectedTimestamp: farFutureTime
        ),

        // Data type tests
        EstimateTestCase(
            name: "String data",
            timestamp: futureTime + 8.0,
            priority: CallbackScheduler.Priority.High,
            executionEffort: 1000,
            data: "string data",
            expectNil: false,
            expectedFee: 1.0,
            expectedTimestamp: futureTime + 8.0
        ),
        EstimateTestCase(
            name: "Int data",
            timestamp: futureTime + 9.0,
            priority: CallbackScheduler.Priority.Medium,
            executionEffort: 1000,
            data: 42,
            expectNil: false,
            expectedFee: 0.5,
            expectedTimestamp: futureTime + 9.0
        ),
        EstimateTestCase(
            name: "Array data",
            timestamp: futureTime + 10.0,
            priority: CallbackScheduler.Priority.High,
            executionEffort: 1000,
            data: [1, 2, 3],
            expectNil: false,
            expectedFee: 1.0,
            expectedTimestamp: futureTime + 10.0
        ),
        EstimateTestCase(
            name: "Dictionary data",
            timestamp: futureTime + 11.0,
            priority: CallbackScheduler.Priority.Medium,
            executionEffort: 1000,
            data: {"key": "value"},
            expectNil: false,
            expectedFee: 0.5,
            expectedTimestamp: futureTime + 11.0
        )
    ]

    for testCase in estimateTestCases {
        runEstimateTestCase(testCase: testCase)
    }
}

access(all) fun runEstimateTestCase(testCase: EstimateTestCase) {
    Test.log("Running test: ".concat(testCase.name))
    
    let result = CallbackScheduler.estimate(
        data: testCase.data,
        timestamp: testCase.timestamp,
        priority: testCase.priority,
        executionEffort: testCase.executionEffort
    )
    
    if testCase.expectNil {
        Test.expect(result, Test.beNil())
    } else {
        Test.expect(result, Test.beNotNil())
        
        if let estimate = result {
            if let expectedFee = testCase.expectedFee {
                Test.assertEqual(expectedFee, estimate.flowFee)
            }
            
            if let expectedTimestamp = testCase.expectedTimestamp {
                Test.assertEqual(expectedTimestamp, estimate.timestamp)
            }
        }
    }
}
