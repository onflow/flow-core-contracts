import Test
import BlockchainHelpers
import "FlowTransactionScheduler"
import "FlowToken"
import "FlowTransactionSchedulerUtils"

import "scheduled_transaction_test_helpers.cdc"
import "evm_test_helpers.cdc"

access(all) var startingHeight: UInt64 = 0

access(all) let depositFLOWEnum: UInt8 = 0
access(all) let withdrawFLOWEnum: UInt8 = 1
access(all) let callEnum: UInt8 = 2

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

    fundAccountWithFlow(to: admin.address, amount: 10000.0)

    startingHeight = getCurrentBlockHeight()

}

/** ---------------------------------------------------------------------------------
 Transaction handler integration tests
 --------------------------------------------------------------------------------- */

access(all) fun testCOAScheduledTransactions() {

    let currentTime = getTimestamp()
    let timeInFuture = currentTime + futureDelta

    setupCOATransaction(amount: 100.0)

    // Schedule high priority transaction
    scheduleCOATransaction(
        timestamp: timeInFuture,
        fee: feeAmount,
        effort: basicEffort,
        priority: highPriority,
        coaTXTypeEnum: depositFLOWEnum,
        amount: 100.0,
        callToEVMAddress: nil,
        data: nil,
        gasLimit: nil,
        value: nil,
        testName: "Test COA Transaction Scheduling: Deposit FLOW",
        failWithErr: nil
    )
}
