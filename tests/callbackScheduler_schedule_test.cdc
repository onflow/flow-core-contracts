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
 Callback scheduler schedule tests
 --------------------------------------------------------------------------------- */

// Callback structure for tests
access(all) struct Callback {
    access(all) var id: UInt64?
    access(all) let requestedDelta: UFix64
    access(all) let priority: UInt8
    access(all) let executionEffort: UInt64
    access(all) let data: AnyStruct?
    access(all) let fees: UFix64
    access(all) let failWithErr: String?

    access(all) init(
        requestedDelta: UFix64,
        priority: UInt8,
        executionEffort: UInt64,
        data: AnyStruct?,
        fees: UFix64,
        failWithErr: String?
    ) {
        self.id = nil
        self.requestedDelta = requestedDelta
        self.priority = priority
        self.executionEffort = executionEffort
        self.data = data
        self.fees = fees
        self.failWithErr = failWithErr
    }

    access(all) fun setID(id: UInt64?) {
        self.id = id
    }
}

// Test case structure for schedule and effort used tests
access(all) struct ScheduleAndEffortUsedTestCase {
    access(all) let name: String
    access(all) let callbacks: [Callback]
    access(all) let callbacksIndicesToCancel: [Int]
    access(all) let expectedAvailableEfforts: {UFix64: {UInt8: UInt64}}
    access(all) let expectedPendingQueues: {UFix64: [UInt64]}
    access(all) let expectedPendingQueueAfterExecution: [UInt64]

    access(all) init(
        name: String,
        callbacks: [Callback],
        callbacksIndicesToCancel: [Int],
        expectedAvailableEfforts: {UFix64: {UInt8: UInt64}},
        expectedPendingQueues: {UFix64: [UInt64]},
        expectedPendingQueueAfterExecution: [UInt64]
    ) {
        self.name = name
        self.callbacks = callbacks
        self.callbacksIndicesToCancel = callbacksIndicesToCancel
        self.expectedAvailableEfforts = expectedAvailableEfforts
        self.expectedPendingQueues = expectedPendingQueues
        self.expectedPendingQueueAfterExecution = expectedPendingQueueAfterExecution
    }
    
    access(all) fun setID(index: Int, id: UInt64?) {
        self.callbacks[index].setID(id: id)
    }
}

access(all) fun runScheduleAndEffortUsedTestCase(testCase: ScheduleAndEffortUsedTestCase, currentTimestamp: UFix64): UFix64 {
    
    var scheduleIndex = 0
    var idToSet = 1
    for callback in testCase.callbacks {
        scheduleCallback(
            timestamp: currentTimestamp + callback.requestedDelta,
            fee: callback.fees,
            effort: callback.executionEffort,
            priority: callback.priority,
            data: callback.data,
            testName: testCase.name,
            failWithErr: callback.failWithErr
        )
        if callback.failWithErr == nil {
            testCase.setID(index: scheduleIndex, id: UInt64(idToSet))
            idToSet = idToSet + 1
        }
        scheduleIndex = scheduleIndex + 1
    }

    for cancelIndex in testCase.callbacksIndicesToCancel {
        cancelCallback(id: testCase.callbacks[cancelIndex].id!, failWithErr: nil)
        testCase.setID(index: cancelIndex, id: nil)
    }

    for delta in testCase.expectedAvailableEfforts.keys {
        for priority in testCase.expectedAvailableEfforts[delta]!.keys {
            let expectedEffort = testCase.expectedAvailableEfforts[delta]![priority]!
            let actualEffort = getSlotAvailableEffort(timestamp: currentTimestamp + delta, priority: priority)
            
            // check available efforts
            Test.assert(expectedEffort == actualEffort,
                message: "available effort mismatch for test case: \(testCase.name) with timestamp \(currentTimestamp + delta) and priority \(priority). Expected \(expectedEffort) but got \(actualEffort)"
            )
        }
    }

    Test.moveTime(by: Fix64(futureDelta-30.0))

    let sortedTimestamps = FlowCallbackScheduler.SortedTimestamps()
    for delta in testCase.expectedPendingQueues.keys {
        sortedTimestamps.add(timestamp: currentTimestamp + delta)
    }

    for timestamp in sortedTimestamps.getAll() {
        // move time forward to trigger execution eligibility
        while getTimestamp() < timestamp {
            Test.moveTime(by: Fix64(1.0))
        }

        let expectedPendingQueue = testCase.expectedPendingQueues[timestamp - currentTimestamp]!
        let actualPendingQueue = getPendingQueue()
        Test.assert(expectedPendingQueue.length == actualPendingQueue.length,
                message: "pending queue length mismatch for test case: \(testCase.name) with timestamp \(timestamp). Expected \(expectedPendingQueue.length) but got \(actualPendingQueue.length)"
        )

        for id in expectedPendingQueue {
            Test.assert(actualPendingQueue.contains(id),
                message: "pending queue element mismatch for test case: \(testCase.name) with timestamp \(timestamp). Expected \(id) but could not find it in the actual pending queue"
            )
        }
    }

    // process callbacks
    processCallbacks()

    var numberOfCallbacksExecuted = 0

    for callback in testCase.callbacks {
        if callback.id != nil && numberOfCallbacksExecuted < collectionTransactionsLimit && UInt64(numberOfCallbacksExecuted)*maxEffort < collectionEffortLimit - maxEffort {
            numberOfCallbacksExecuted = numberOfCallbacksExecuted + 1
            if callback.data != nil {
                if callback.data as! String == "cancel" {
                    executeCallback(id: callback.id!, testName: testCase.name, failWithErr: "Callback must be in a scheduled state in order to be canceled")
                    continue
                } else if callback.data as! String == "fail" {
                    executeCallback(id: callback.id!, testName: testCase.name, failWithErr: "Callback \(callback.id!) failed")
                    continue
                }
            }
            executeCallback(id: callback.id!, testName: testCase.name, failWithErr: nil)
        }
    }

    // move time forward by 20.0
    Test.moveTime(by: Fix64(20.0))

    // get actual pending queue
    let actualPendingQueueAfterExecution = getPendingQueue()
    Test.assert(testCase.expectedPendingQueueAfterExecution.length == actualPendingQueueAfterExecution.length,
        message: "pending queue after execution length mismatch for test case: \(testCase.name) after execution. Expected \(testCase.expectedPendingQueueAfterExecution.length) but got \(actualPendingQueueAfterExecution.length)"
    )
    for id in testCase.expectedPendingQueueAfterExecution {
        Test.assert(actualPendingQueueAfterExecution.contains(id),
            message: "pending queue after execution element mismatch for test case: \(testCase.name). Expected \(id) but could not find it in the actual pending queue"
        )
    }

    return getTimestamp()
}

access(all) fun testScheduleAndEffortUsed() {

    var startingHeight = getCurrentBlockHeight()

    // Common callbacks that we will use multiple times in certain test cases

    let lowCallbackWith300Effort = Callback(
        requestedDelta: futureDelta,
        priority: lowPriority,
        executionEffort: 300,
        data: testData,
        fees: feeAmount,
        failWithErr: nil
    )

    let mediumCallbackWith4000Effort = Callback(
        requestedDelta: futureDelta,
        priority: mediumPriority,
        executionEffort: 4000,
        data: testData,
        fees: feeAmount,
        failWithErr: nil
    )

    let highCallbackWith8000Effort = Callback(
        requestedDelta: futureDelta,
        priority: highPriority,
        executionEffort: 8000,
        data: testData,
        fees: feeAmount,
        failWithErr: nil
    )

    let testCases: [ScheduleAndEffortUsedTestCase] = [
        // Low priority only test cases
        ScheduleAndEffortUsedTestCase(
            name: "Low priority: Zero fees and zero effort fails with no effort used",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 1000,
                    data: testData,
                    fees: 0.0,
                    failWithErr: "Insufficient fees: The Fee balance of 0.00000000 is not sufficient to pay the required amount of 0.00010000 for execution of the callback."
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 0,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: "Invalid execution effort: 0 is less than the minimum execution effort of 10"
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: []
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Low priority: Min effort fits in slot and uses min effort",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 10,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort - 10
                }
            },
            expectedPendingQueues: {
                futureDelta: [1]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Low priority: Max effort fits in slot and uses max effort. Other low priority callbacks are scheduled for later",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: lowPriorityMaxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 10,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: 0
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort - 10
                }
            },
            expectedPendingQueues: {
                futureDelta: [1],
                futureDelta + 1.0: [1,2]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Low Priority: Greater than max effort Fails",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: lowPriorityMaxEffort + 1,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: "Invalid execution effort: 5001 is greater than the priority's max effort of 5000"
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: []
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Low Priority: Many low priority callbacks scheduled for same timestamp",
            callbacks: [
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                lowCallbackWith300Effort,
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 300,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: 200
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: 4700
                }
            },
            expectedPendingQueues: {
                futureDelta: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16],
                futureDelta + 1.0: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17]
            },
            expectedPendingQueueAfterExecution: []
        ),
        
        // Medium priority only test cases
        ScheduleAndEffortUsedTestCase(
            name: "Medium priority: Min effort fits in slot and uses min effort",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 10,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort - 10,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [1]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Medium priority: Max effort fits in slot and uses max effort. Other medium priority callbacks are scheduled for later",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: maxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: maxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort - 4999,
                    mediumPriority: mediumPriorityMaxEffort - maxEffort,
                    lowPriority: lowPriorityMaxEffort
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort - 4999,
                    mediumPriority: mediumPriorityMaxEffort - maxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [1],
                futureDelta + 1.0: [1,2]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Medium Priority: Greater than max effort Fails",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: maxEffort + 1,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: "Invalid execution effort: \(maxEffort + 1) is greater than the maximum callback effort of 9999"
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: []
            },
            expectedPendingQueueAfterExecution: []
        ),
        
        // Medium Priority: Many medium priority callbacks scheduled for same timestamp
        ScheduleAndEffortUsedTestCase(
            name: "Medium Priority: Many medium priority callbacks scheduled for same timestamp",
            callbacks: [
                mediumCallbackWith4000Effort,
                mediumCallbackWith4000Effort,
                mediumCallbackWith4000Effort,
                mediumCallbackWith4000Effort,
                mediumCallbackWith4000Effort,
                mediumCallbackWith4000Effort,
                mediumCallbackWith4000Effort,
                mediumCallbackWith4000Effort,
                mediumCallbackWith4000Effort,
                mediumCallbackWith4000Effort
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort-7000,
                    mediumPriority: 3000,
                    lowPriority: lowPriorityMaxEffort
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort-7000,
                    mediumPriority: 3000,
                    lowPriority: lowPriorityMaxEffort
                },
                futureDelta + 2.0: {
                    highPriority: highPriorityMaxEffort-7000,
                    mediumPriority: 3000,
                    lowPriority: lowPriorityMaxEffort
                },
                futureDelta + 3.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: 11000,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [1,2,3],
                futureDelta + 1.0: [1,2,3,4,5,6],
                futureDelta + 2.0: [1,2,3,4,5,6,7,8,9],
                futureDelta + 3.0: [1,2,3,4,5,6,7,8,9,10]
            },
            expectedPendingQueueAfterExecution: []
        ),
        
        // High priority only test cases
        ScheduleAndEffortUsedTestCase(
            name: "High priority: Min effort fits in slot and uses min effort",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 10,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort - 10,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [1]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "High priority: Max effort fits in slot and uses max effort. Other high priority callbacks fail in the same slot",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: maxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: maxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: maxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: maxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: "Invalid execution effort: \(maxEffort) is greater than the priority's available effort for the requested timestamp."
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort - 3*maxEffort,
                    mediumPriority: mediumPriorityEffortReserve + 3,
                    lowPriority: lowPriorityMaxEffort
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [1,2,3],
                futureDelta + 1.0: [1,2,3]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "High Priority: Greater than max effort Fails",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: maxEffort + 1,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: "Invalid execution effort: \(maxEffort + 1) is greater than the maximum callback effort of 9999"
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: []
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "High Priority: Many high priority callbacks scheduled for the same timestamp",
            callbacks: [
                highCallbackWith8000Effort,
                highCallbackWith8000Effort,
                highCallbackWith8000Effort,
                Callback(
                    requestedDelta: futureDelta + 1.0,
                    priority: highPriority,
                    executionEffort: 8000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: 6000,
                    mediumPriority: 11000,
                    lowPriority: lowPriorityMaxEffort
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort - 8000,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [1,2,3],
                futureDelta + 1.0: [1,2,3,4]
            },
            expectedPendingQueueAfterExecution: []
        ),
        
        // Mixed priority test cases - testing shared limit usage
        ScheduleAndEffortUsedTestCase(
            name: "Mixed priorities: High priorities use shared limit, medium priority uses reserve",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 9000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 9000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 9000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 3000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: mediumPriorityEffortReserve,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 1000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 1000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 1000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: "Invalid execution effort: 1000 is greater than the priority's available effort for the requested timestamp."
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: 0,
                    mediumPriority: 0,
                    lowPriority: 0
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort - 1000,
                    lowPriority: lowPriorityMaxEffort - 1000
                }
            },
            expectedPendingQueues: {
                futureDelta: [1,2,3,4,5],
                futureDelta + 1.0: [1,2,3,4,5,6,7]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Mixed priorities: Medium uses shared limit, high priority fails in the same slot",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 9000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 6000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 9000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 9000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 2001,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: "Invalid execution effort: 2001 is greater than the priority's available effort for the requested timestamp."
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 2000,
                    data: testData,
                    fees: feeAmount,    
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: 0,
                    mediumPriority: 0,
                    lowPriority: 0
                }
            },
            expectedPendingQueues: {
                futureDelta: [1,2,3,4,5],
                futureDelta + 1.0: [1,2,3,4,5]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Mixed priorities: High and medium use most of shared limit, low priority fits in remaining but doesn't use the high or medium effort",
            callbacks: [
                highCallbackWith8000Effort,
                highCallbackWith8000Effort,
                highCallbackWith8000Effort,
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: mediumPriorityEffortReserve + 4000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 2001,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 2001,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 2000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: 2000,
                    mediumPriority: 2000,
                    lowPriority: 0
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort-2001,
                    lowPriority: lowPriorityMaxEffort - 2001
                }
            },
            expectedPendingQueues: {
                futureDelta: [1,2,3,4,7],
                futureDelta + 1.0: [1,2,3,4,5,6,7]
            },
            expectedPendingQueueAfterExecution: []
        ),
        
        // Test cases for low priority callbacks getting rescheduled by higher priority callbacks
        ScheduleAndEffortUsedTestCase(
            name: "Low priority gets rescheduled: Low priority fills slot, high and medium priority pushes it to next timestamp",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: lowPriorityMaxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 9000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 9000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 9000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 8000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: 0,
                    mediumPriority: 0,
                    lowPriority: 0
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: 0
                }
            },
            expectedPendingQueues: {
                futureDelta: [2,3,4,5],
                futureDelta + 1.0: [1,2,3,4,5]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Low priority gets rescheduled: Multiple low priority callbacks get pushed by high and medium priority",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 2000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 2000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                highCallbackWith8000Effort,
                highCallbackWith8000Effort,
                highCallbackWith8000Effort,
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 6000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 2000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: 0,
                    mediumPriority: 3000,
                    lowPriority: 1000
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: 3000
                }
            },
            expectedPendingQueues: {
                futureDelta: [1,3,4,5,6,7],
                futureDelta + 1.0: [1,2,3,4,5,6,7]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Low priority gets rescheduled: Low Priorities get pushed to multiple slots",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 3000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 2000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 8000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 7000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta + 1.0,
                    priority: highPriority,
                    executionEffort: 8000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta + 1.0,
                    priority: highPriority,
                    executionEffort: 8000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta + 1.0,
                    priority: highPriority,
                    executionEffort: 8000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta + 1.0,
                    priority: highPriority,
                    executionEffort: 6000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta + 1.0,
                    priority: mediumPriority,
                    executionEffort: mediumPriorityEffortReserve - 2000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 9500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                // Should push 1 and 2 to the next two timestamps
                 Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 9500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: 1000,
                    mediumPriority: 0,
                    lowPriority: 1000
                },
                futureDelta + 1.0: {
                    highPriority: 0,
                    mediumPriority: 2000,
                    lowPriority: 0
                },
                futureDelta + 2.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: 2000
                }
            },
            expectedPendingQueues: {
                futureDelta: [3,4,10,11],
                futureDelta + 1.0: [2,3,4,5,6,7,8,9,10,11],
                futureDelta + 2.0: [1,2,3,4,5,6,7,8,9,10,11]
            },
            expectedPendingQueueAfterExecution: []
        ),
        // Self-canceling callback test case
        ScheduleAndEffortUsedTestCase(
            name: "Cancel Tests: Callback tries to cancel itself during execution: Should fail",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 3000,
                    data: "cancel",
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort - 3000
                }
            },
            expectedPendingQueues: {
                futureDelta: [1]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Cancel Tests: High priority callback canceled after scheduling",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 5000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [0],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: []
            },
            expectedPendingQueueAfterExecution: []
        ),
        
        ScheduleAndEffortUsedTestCase(
            name: "Cancel Tests: Medium priority callback canceled after scheduling",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 3000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [0],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: []
            },
            expectedPendingQueueAfterExecution: []
        ),
        
        ScheduleAndEffortUsedTestCase(
            name: "Cancel Tests: Low priority callback canceled after scheduling",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 2000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [0],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: []
            },
            expectedPendingQueueAfterExecution: []
        ),
        
        ScheduleAndEffortUsedTestCase(
            name: "Cancel Tests: Multiple callbacks with one canceled",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 4000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 2500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 1500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [1],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort - 4000,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort - 1500
                }
            },
            expectedPendingQueues: {
                futureDelta: [1, 3]
            },
            expectedPendingQueueAfterExecution: []
        ),
        
        ScheduleAndEffortUsedTestCase(
            name: "Cancel Tests: Multiple callbacks with multiple canceled",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 4000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 2500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 1500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [0, 2],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort - 2500,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [2]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Cancel Tests: Callback canceled with different timestamp",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta + 50.0,
                    priority: highPriority,
                    executionEffort: 6000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [0],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                },
                futureDelta + 50.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta + 50.0: []
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Cancel Tests: Cancel a callback that was moved to a different timestamp by another callback",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: lowPriorityMaxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                highCallbackWith8000Effort,
                highCallbackWith8000Effort,
                highCallbackWith8000Effort,
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 6000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: lowPriorityMaxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [0],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: 0,
                    mediumPriority: 0,
                    lowPriority: 0
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [2,3,4,5,6],
                futureDelta + 1.0: [2,3,4,5,6]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Fail Tests: Callback with fail data should fail during execution",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 2000,
                    data: "fail",
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort - 2000,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [1]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Schedule Tests: Callback schedules another callback during execution",
            callbacks: [
                Callback(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 3000,
                    data: "schedule",
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            callbacksIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort - 3000,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [1]
            },
            expectedPendingQueueAfterExecution: [2]
        )
    ]

    /// Test case to test callbacks over collection effort limit
    ///
    var callbacksOverCollectionEffortLimit: [Callback] = []
    while UInt64(callbacksOverCollectionEffortLimit.length)*maxEffort <= collectionEffortLimit + maxEffort*2 {
        callbacksOverCollectionEffortLimit.append(Callback(
            requestedDelta: futureDelta+UFix64(callbacksOverCollectionEffortLimit.length),
            priority: mediumPriority,
            executionEffort: maxEffort,
            data: testData,
            fees: feeAmount,
            failWithErr: nil
        ))
    }

    var expectedPendingQueue: {UFix64: [UInt64]} = {}
    var queue: [UInt64] = []
    var i: Int = 1
    while i <= callbacksOverCollectionEffortLimit.length - 3 {
        queue.append(UInt64(i))
        i = i + 1
    }
    expectedPendingQueue[futureDelta+UFix64(callbacksOverCollectionEffortLimit.length)] = queue

    testCases.append(ScheduleAndEffortUsedTestCase(
        name: "Collection Limit Tests: Callbacks over collection effort limit",
        callbacks: callbacksOverCollectionEffortLimit,
        callbacksIndicesToCancel: [],
        expectedAvailableEfforts: {},
        expectedPendingQueues: expectedPendingQueue,
        expectedPendingQueueAfterExecution: [UInt64(callbacksOverCollectionEffortLimit.length-2), UInt64(callbacksOverCollectionEffortLimit.length-1), UInt64(callbacksOverCollectionEffortLimit.length)]
    ))

    /// Test case to test callbacks over collection transaction limit
    ///
    var callbacksOverCollectionTxLimit: [Callback] = []
    while callbacksOverCollectionTxLimit.length < collectionTransactionsLimit + 2 {
        callbacksOverCollectionTxLimit.append(Callback(
            requestedDelta: futureDelta+UFix64(callbacksOverCollectionTxLimit.length),
            priority: mediumPriority,
            executionEffort: 4000,
            data: testData,
            fees: feeAmount,
            failWithErr: nil
        ))
    }

    expectedPendingQueue = {}
    queue = []
    i = 1
    while i <= collectionTransactionsLimit {
        queue.append(UInt64(i))
        i = i + 1
    }
    expectedPendingQueue[futureDelta+UFix64(callbacksOverCollectionTxLimit.length)] = queue

    testCases.append(ScheduleAndEffortUsedTestCase(
        name: "Collection Limit Tests: Callbacks over collection transaction limit",
        callbacks: callbacksOverCollectionTxLimit,
        callbacksIndicesToCancel: [],
        expectedAvailableEfforts: {},
        expectedPendingQueues: expectedPendingQueue,
        expectedPendingQueueAfterExecution: [UInt64(collectionTransactionsLimit+1), UInt64(collectionTransactionsLimit+2)]
    ))

    var currentTimestamp = getTimestamp()

    for testCase in testCases {
        currentTimestamp = runScheduleAndEffortUsedTestCase(testCase: testCase, currentTimestamp: currentTimestamp)
        if startingHeight < getCurrentBlockHeight() {
            Test.reset(to: startingHeight)
        }
    }
}