import Test
import BlockchainHelpers
import "FlowTransactionScheduler"
import "FlowToken"
import "TestFlowScheduledTransactionHandler"

import "scheduled_transaction_test_helpers.cdc"

access(all)
fun setup() {

    var err = Test.deployContract(
        name: "FlowTransactionScheduler",
        path: "../contracts/FlowTransactionScheduler.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "FlowTransactionSchedulerUtils",
        path: "../contracts/FlowTransactionSchedulerUtils.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "TestFlowScheduledTransactionHandler",
        path: "../contracts/testContracts/TestFlowScheduledTransactionHandler.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    fundAccountWithFlow(to: admin.address, amount: 10000.0)
}

/** ---------------------------------------------------------------------------------
 Transaction scheduler schedule tests
 --------------------------------------------------------------------------------- */

// Transaction structure for tests
access(all) struct ScheduledTransaction {
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
    access(all) let transactions: [ScheduledTransaction]
    access(all) let transactionsIndicesToCancel: [Int]
    access(all) let expectedAvailableEfforts: {UFix64: {UInt8: UInt64}}
    access(all) let expectedPendingQueues: {UFix64: [UInt64]}
    access(all) let expectedPendingQueueAfterExecution: [UInt64]

    access(all) init(
        name: String,
        transactions: [ScheduledTransaction],
        transactionsIndicesToCancel: [Int],
        expectedAvailableEfforts: {UFix64: {UInt8: UInt64}},
        expectedPendingQueues: {UFix64: [UInt64]},
        expectedPendingQueueAfterExecution: [UInt64]
    ) {
        self.name = name
        self.transactions = transactions
        self.transactionsIndicesToCancel = transactionsIndicesToCancel
        self.expectedAvailableEfforts = expectedAvailableEfforts
        self.expectedPendingQueues = expectedPendingQueues
        self.expectedPendingQueueAfterExecution = expectedPendingQueueAfterExecution
    }
    
    access(all) fun setID(index: Int, id: UInt64?) {
        self.transactions[index].setID(id: id)
    }
}

access(all) fun runScheduleAndEffortUsedTestCase(testCase: ScheduleAndEffortUsedTestCase, currentTimestamp: UFix64): UFix64 {
    
    var scheduleIndex = 0
    var idToSet = 1
    for tx in testCase.transactions {
        scheduleTransaction(
            timestamp: currentTimestamp + tx.requestedDelta,
            fee: tx.fees,
            effort: tx.executionEffort,
            priority: tx.priority,
            data: tx.data,
            testName: testCase.name,
            failWithErr: tx.failWithErr
        )
        if tx.failWithErr == nil {
            testCase.setID(index: scheduleIndex, id: UInt64(idToSet))
            idToSet = idToSet + 1
        }
        scheduleIndex = scheduleIndex + 1
    }

    for cancelIndex in testCase.transactionsIndicesToCancel {
        cancelTransaction(id: testCase.transactions[cancelIndex].id!, failWithErr: nil)
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

    let sortedTimestamps = FlowTransactionScheduler.SortedTimestamps()
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

    // process transactions
    processTransactions()

    var numberOfTransactionsExecuted = 0

    for tx in testCase.transactions {
        if tx.id != nil && numberOfTransactionsExecuted < collectionTransactionsLimit && UInt64(numberOfTransactionsExecuted)*maxEffort < collectionEffortLimit - maxEffort {
            numberOfTransactionsExecuted = numberOfTransactionsExecuted + 1
            if tx.data != nil {
                if tx.data as! String == "cancel" {
                    executeScheduledTransaction(id: tx.id!, testName: testCase.name, failWithErr: "Transaction must be in a scheduled state in order to be canceled")
                    continue
                } else if tx.data as! String == "fail" {
                    executeScheduledTransaction(id: tx.id!, testName: testCase.name, failWithErr: "Transaction \(tx.id!) failed")
                    continue
                }
            }
            executeScheduledTransaction(id: tx.id!, testName: testCase.name, failWithErr: nil)
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

    // Common transactions that we will use multiple times in certain test cases

    let lowTransactionWith150Effort = ScheduledTransaction(
        requestedDelta: futureDelta,
        priority: lowPriority,
        executionEffort: 150,
        data: testData,
        fees: feeAmount,
        failWithErr: nil
    )

    let mediumTransactionWith2000Effort = ScheduledTransaction(
        requestedDelta: futureDelta,
        priority: mediumPriority,
        executionEffort: 2000,
        data: testData,
        fees: feeAmount,
        failWithErr: nil
    )

    let highTransactionWith4000Effort = ScheduledTransaction(
        requestedDelta: futureDelta,
        priority: highPriority,
        executionEffort: 4000,
        data: testData,
        fees: feeAmount,
        failWithErr: nil
    )

    let testCases: [ScheduleAndEffortUsedTestCase] = [
        // Low priority only test cases
        ScheduleAndEffortUsedTestCase(
            name: "Low priority: Zero fees and zero effort fails with no effort used",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 1000,
                    data: testData,
                    fees: 0.0,
                    failWithErr: "Insufficient fees: The Fee balance of 0.00000000 is not sufficient to pay the required amount of 0.00011000 for execution of the transaction."
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 0,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: "Invalid execution effort: 0 is less than the minimum execution effort of 100"
                )
            ],
            transactionsIndicesToCancel: [],
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
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 100,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort - 100
                }
            },
            expectedPendingQueues: {
                futureDelta: [1]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Low priority: Max effort fits in slot and uses max effort. Other low priority transactions are scheduled for later",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: lowPriorityMaxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: minEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: 0
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort - minEffort
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
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: lowPriorityMaxEffort + 1,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: "Invalid execution effort: \(lowPriorityMaxEffort + 1) is greater than the priority's max effort of \(lowPriorityMaxEffort)"
                )
            ],
            transactionsIndicesToCancel: [],
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
            name: "Low Priority: Many low priority transactions scheduled for same timestamp",
            transactions: [
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                lowTransactionWith150Effort,
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 150,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: 100
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort - 150
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
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: minEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort - minEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [1]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Medium priority: Max effort fits in slot and uses max effort. Other medium priority transactions are scheduled for later",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: mediumPriorityMaxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: mediumPriorityMaxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [],
            // V2: medium pool is independent; high pool is unaffected when medium is full
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: 0,
                    lowPriority: lowPriorityMaxEffort
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: 0,
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
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: maxEffort + 1,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: "Invalid execution effort: \(maxEffort + 1) is greater than the maximum transaction effort of \(maxEffort)"
                )
            ],
            transactionsIndicesToCancel: [],
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
        
        // Medium Priority: Many medium priority transactions scheduled for same timestamp
        ScheduleAndEffortUsedTestCase(
            name: "Medium Priority: Many medium priority transactions scheduled for same timestamp",
            transactions: [
                mediumTransactionWith2000Effort,
                mediumTransactionWith2000Effort,
                mediumTransactionWith2000Effort,
                mediumTransactionWith2000Effort,
                mediumTransactionWith2000Effort,
                mediumTransactionWith2000Effort,
                mediumTransactionWith2000Effort,
                mediumTransactionWith2000Effort,
                mediumTransactionWith2000Effort,
                mediumTransactionWith2000Effort
            ],
            transactionsIndicesToCancel: [],
            // V2: medium pool is independent; high pool is unaffected when medium transactions fill their slots
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: 1500,
                    lowPriority: lowPriorityMaxEffort
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: 1500,
                    lowPriority: lowPriorityMaxEffort
                },
                futureDelta + 2.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: 1500,
                    lowPriority: lowPriorityMaxEffort
                },
                futureDelta + 3.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort - 2000,
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
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: minEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort - minEffort,
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
            name: "High priority: Max effort fits in slot and uses max effort. Other high priority transactions fail in the same slot",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: maxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: maxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: "Invalid execution effort: \(maxEffort) is greater than the priority's available effort for the requested timestamp."
                )
            ],
            transactionsIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort - maxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [1],
                futureDelta + 1.0: [1]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "High Priority: Greater than max effort Fails",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: maxEffort + 1,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: "Invalid execution effort: \(maxEffort + 1) is greater than the maximum transaction effort of 9999"
                )
            ],
            transactionsIndicesToCancel: [],
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
            name: "High Priority: Many high priority transactions scheduled for the same timestamp",
            transactions: [
                highTransactionWith4000Effort,
                highTransactionWith4000Effort,
                highTransactionWith4000Effort,
                ScheduledTransaction(
                    requestedDelta: futureDelta + 1.0,
                    priority: highPriority,
                    executionEffort: 4000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [],
            // V2: high pool is independent; medium pool is unaffected when high transactions fill their slot
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort - 12000,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort
                },
                futureDelta + 1.0: {
                    highPriority: highPriorityMaxEffort - 4000,
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

        // Mixed priority test cases - testing isolated pool behavior
        ScheduleAndEffortUsedTestCase(
            name: "Mixed priorities: High priority pool fills up, medium and low pools are independent",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 9000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 6000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 2500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 1000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 1000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 1000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: "Invalid execution effort: 1000 is greater than the priority's available effort for the requested timestamp."
                )
            ],
            transactionsIndicesToCancel: [],
            // V2: pools are isolated; medium (2500+1000=3500 used, 4000 remaining) and low (1000 used, 1500 remaining)
            // are unaffected when the high pool (9000+6000=15000) is full
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: 0,
                    mediumPriority: 4000,
                    lowPriority: 1500
                }
            },
            expectedPendingQueues: {
                futureDelta: [1,2,3,4,5]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Mixed priorities: Medium priority pool fills up, high priority pool remains independent",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 7500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 9000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 1001,
                    data: testData,
                    fees: feeAmount,
                    // V2: high pool is independent; 6000 remain after 9000 used, so 1001 fits
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 1000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [],
            // V2: high pool (9000+1001+1000=11001 used, 3999 remaining), medium pool (7500 used, 0 remaining)
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: 3999,
                    mediumPriority: 0,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [1,2,3,4]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Mixed priorities: High medium and low priority pools are all independent",
            transactions: [
                highTransactionWith4000Effort,
                highTransactionWith4000Effort,
                highTransactionWith4000Effort,
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 4500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 1001,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 1001,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 1000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [],
            // V2: all 7 txs fit at futureDelta; high=12000 used, medium=4500+1001=5501 used, low=1001+1000=2001 used
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: 3000,
                    mediumPriority: 1999,
                    lowPriority: 499
                }
            },
            expectedPendingQueues: {
                futureDelta: [1,2,3,4,5,6,7]
            },
            expectedPendingQueueAfterExecution: []
        ),
        // Self-canceling transaction test case
        ScheduleAndEffortUsedTestCase(
            name: "Cancel Tests: Transaction tries to cancel itself during execution: Should fail",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 1500,
                    data: "cancel",
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort,
                    lowPriority: lowPriorityMaxEffort - 1500
                }
            },
            expectedPendingQueues: {
                futureDelta: [1]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Cancel Tests: High priority transaction canceled after scheduling",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 5000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [0],
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
            name: "Cancel Tests: Medium priority transaction canceled after scheduling",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 3000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [0],
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
            name: "Cancel Tests: Low priority transaction canceled after scheduling",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 2000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [0],
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
            name: "Cancel Tests: Multiple transactions with one canceled",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 4000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 2500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 1500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [1],
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
            name: "Cancel Tests: Multiple transactions with multiple canceled",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 4000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 2500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: 1500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [0, 2],
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
            name: "Cancel Tests: Transaction canceled with different timestamp",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta + 50.0,
                    priority: highPriority,
                    executionEffort: 6000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [0],
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
            name: "Cancel Tests: Cancel a low priority transaction that filled the low pool while high pool is also full",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: lowPriority,
                    executionEffort: lowPriorityMaxEffort,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                highTransactionWith4000Effort,
                highTransactionWith4000Effort,
                highTransactionWith4000Effort,
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 3000,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                ),
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 2500,
                    data: testData,
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [0],
            // V2: tx1 (low) stays at futureDelta; after cancel: low pool (2500) restored; high=0, medium=5000 remaining
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: 0,
                    mediumPriority: 5000,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [2,3,4,5,6]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Fail Tests: Transaction with fail data should fail during execution",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: mediumPriority,
                    executionEffort: 1000,
                    data: "fail",
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort,
                    mediumPriority: mediumPriorityMaxEffort - 1000,
                    lowPriority: lowPriorityMaxEffort
                }
            },
            expectedPendingQueues: {
                futureDelta: [1]
            },
            expectedPendingQueueAfterExecution: []
        ),
        ScheduleAndEffortUsedTestCase(
            name: "Schedule Tests: Transaction schedules another transaction during execution",
            transactions: [
                ScheduledTransaction(
                    requestedDelta: futureDelta,
                    priority: highPriority,
                    executionEffort: 1500,
                    data: "schedule",
                    fees: feeAmount,
                    failWithErr: nil
                )
            ],
            transactionsIndicesToCancel: [],
            expectedAvailableEfforts: {
                futureDelta: {
                    highPriority: highPriorityMaxEffort - 1500,
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

    /// Test case to test transactions over collection effort limit
    ///
    var transactionsOverCollectionEffortLimit: [ScheduledTransaction] = []
    while UInt64(transactionsOverCollectionEffortLimit.length)*mediumPriorityMaxEffort <= collectionEffortLimit + mediumPriorityMaxEffort*2 {
        transactionsOverCollectionEffortLimit.append(ScheduledTransaction(
            requestedDelta: futureDelta+UFix64(transactionsOverCollectionEffortLimit.length),
            priority: mediumPriority,
            executionEffort: mediumPriorityMaxEffort,
            data: testData,
            fees: feeAmount,
            failWithErr: nil
        ))
    }

    var expectedPendingQueue: {UFix64: [UInt64]} = {}
    var queue: [UInt64] = []
    var i: Int = 1
    while i <= transactionsOverCollectionEffortLimit.length - 3 {
        queue.append(UInt64(i))
        i = i + 1
    }
    expectedPendingQueue[futureDelta+UFix64(transactionsOverCollectionEffortLimit.length)] = queue

    testCases.append(ScheduleAndEffortUsedTestCase(
        name: "Collection Limit Tests: Transactions over collection effort limit",
        transactions: transactionsOverCollectionEffortLimit,
        transactionsIndicesToCancel: [],
        expectedAvailableEfforts: {},
        expectedPendingQueues: expectedPendingQueue,
        expectedPendingQueueAfterExecution: [UInt64(transactionsOverCollectionEffortLimit.length-2), UInt64(transactionsOverCollectionEffortLimit.length-1), UInt64(transactionsOverCollectionEffortLimit.length)]
    ))

    /// Test case to test transactions over collection transaction limit
    ///
    var transactionsOverCollectionTxLimit: [ScheduledTransaction] = []
    while transactionsOverCollectionTxLimit.length < collectionTransactionsLimit + 2 {
        transactionsOverCollectionTxLimit.append(ScheduledTransaction(
            requestedDelta: futureDelta+UFix64(transactionsOverCollectionTxLimit.length),
            priority: mediumPriority,
            executionEffort: 2000,
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
    expectedPendingQueue[futureDelta+UFix64(transactionsOverCollectionTxLimit.length)] = queue

    testCases.append(ScheduleAndEffortUsedTestCase(
        name: "Collection Limit Tests: Transactions over collection transaction limit",
        transactions: transactionsOverCollectionTxLimit,
        transactionsIndicesToCancel: [],
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