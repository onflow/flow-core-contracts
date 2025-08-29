import Test
import "FlowCallbackScheduler"

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

access(all) let futureDelta = 100.0
access(all) var futureTime = 0.0

access(all) var feeAmount = 10.0

/** ---------------------------------------------------------------------------------
 Test helper functions
 --------------------------------------------------------------------------------- */

// Helper functions for scheduling a callback
access(all) fun scheduleCallback(
    timestamp: UFix64,
    fee: UFix64,
    effort: UInt64,
    priority: UInt8,
    data: AnyStruct?,
    testName: String,
    failWithErr: String?
) {
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/callbackScheduler/schedule_callback.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [timestamp, fee, effort, priority, data],
    )
    var result = Test.executeTransaction(tx)

    if let error = failWithErr {
        // log(error)
        // log(result.error!.message)
        Test.expect(result, Test.beFailed())
        Test.assertError(
            result,
            errorMessage: error
        )
    
    } else {
        if result.error != nil {
            Test.assert(result.error == nil, message: "Transaction failed with error: \(result.error!.message) for test case: \(testName)")
        }
    }
}

access(all) fun cancelCallback(id: UInt64, failWithErr: String?) {
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/callbackScheduler/cancel_callback.cdc"),
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [id],
    )
    var result = Test.executeTransaction(tx)

    if let error = failWithErr {
        Test.expect(result, Test.beFailed())
        Test.assertError(
            result,
            errorMessage: error
        )
    
    } else {
        Test.expect(result, Test.beSucceeded())
    }
}

access(all) fun processCallbacks(): Test.TransactionResult {
    let processCallbackCode = Test.readFile("../transactions/callbackScheduler/admin/process_callback.cdc")
    let processTx = Test.Transaction(
        code: processCallbackCode,
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: []
    )
    let processResult = Test.executeTransaction(processTx)
    Test.expect(processResult, Test.beSucceeded())
    return processResult
}

access(all) fun executeCallback(
    id: UInt64, 
    testName: String,
    failWithErr: String?
) {
    let executeCallbackCode = Test.readFile("../transactions/callbackScheduler/admin/execute_callback.cdc")
    let executeTx = Test.Transaction(
        code: executeCallbackCode,
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [id]
    )
    var result = Test.executeTransaction(executeTx)
    if let error = failWithErr {
        // log(error)
        // log(result.error!.message)
        Test.expect(result, Test.beFailed())
        Test.assertError(
            result,
            errorMessage: error
        )
    
    } else {
        if result.error != nil {
            Test.assert(result.error == nil, message: "Transaction failed with error: \(result.error!.message) for test case: \(testName)")
        }
    }
}

access(all) fun setConfigDetails(
    slotSharedEffortLimit: UInt64?,
    priorityEffortReserve: {UInt8: UInt64}?,
    priorityEffortLimit: {UInt8: UInt64}?,
    minimumExecutionEffort: UInt64?,
    priorityFeeMultipliers: {UInt8: UFix64}?,
    refundMultiplier: UFix64?,
    canceledCallbacksLimit: UInt?,
    shouldFail: String?
) {
    let setConfigDetailsCode = Test.readFile("../transactions/callbackScheduler/admin/set_config_details.cdc")
    let setConfigDetailsTx = Test.Transaction(
        code: setConfigDetailsCode,
        authorizers: [serviceAccount.address],
        signers: [serviceAccount],
        arguments: [slotSharedEffortLimit, priorityEffortReserve, priorityEffortLimit, minimumExecutionEffort, priorityFeeMultipliers, refundMultiplier, canceledCallbacksLimit]
    )
    let setConfigDetailsResult = Test.executeTransaction(setConfigDetailsTx)
    if let error = shouldFail {
        // log(error)
        // log(setConfigDetailsResult.error!.message)
        Test.expect(setConfigDetailsResult, Test.beFailed())
        // Check error
        Test.assertError(
            setConfigDetailsResult,
            errorMessage: error
        )
    } else {
        Test.expect(setConfigDetailsResult, Test.beSucceeded())
    }
}

access(all) fun getConfigDetails(): {FlowCallbackScheduler.SchedulerConfig} {
    var config = _executeScript(
        "../transactions/callbackScheduler/scripts/get_config.cdc",
        []
    ).returnValue! as! {FlowCallbackScheduler.SchedulerConfig}
    return config
}

access(all) fun getSizeOfData(data: AnyStruct): UFix64 {
    var size = _executeScript(
        "./scripts/get_data_size.cdc",
        [data]
    ).returnValue! as! UFix64
    return size
}

access(all) fun getStatus(id: UInt64): UInt8? {
    var status = _executeScript(
        "../transactions/callbackScheduler/scripts/get_status.cdc",
        [id]
    ).returnValue as? UInt8
    return status
}

access(all) fun getCallbackData(id: UInt64): FlowCallbackScheduler.CallbackData? {
    var data = _executeScript(
        "../transactions/callbackScheduler/scripts/get_callback_data.cdc",
        [id]
    ).returnValue as? FlowCallbackScheduler.CallbackData
    return data
}

access(all) fun getCallbacksForTimeframe(startTimestamp: UFix64, endTimestamp: UFix64): {UFix64: {UInt8: [UInt64]}} {
    var result = _executeScript(
        "../transactions/callbackScheduler/scripts/get_callbacks_for_timeframe.cdc",
        [startTimestamp, endTimestamp]
    )
    return result.returnValue! as! {UFix64: {UInt8: [UInt64]}}
}

access(all) fun getCanceledCallbacks(): [UInt64] {
    var result = _executeScript(
        "../transactions/callbackScheduler/scripts/get_canceled_callbacks.cdc",
        []
    )
    return result.returnValue! as! [UInt64]
}

access(all) fun getSlotAvailableEffort(timestamp: UFix64, priority: UInt8): UInt64 {
    var result = _executeScript(
        "../transactions/callbackScheduler/scripts/get_slot_available_effort.cdc",
        [timestamp, priority]
    )
    Test.expect(result, Test.beSucceeded())

    var effort = result.returnValue! as! UInt64
    return effort
}

access(all) fun getPendingQueue(): [UInt64] {

    var result = _executeScript(
        "./scripts/get_pending_queue.cdc",
        []
    )
    Test.expect(result, Test.beSucceeded())

    return result.returnValue! as! [UInt64]
}

access(all) fun getTimestamp(): UFix64 {
    var timestamp = _executeScript(
        "./scripts/get_timestamp.cdc",
        []
    ).returnValue! as! UFix64
    return timestamp!
}

access(all) fun getBalance(account: Address): UFix64 {
    var balance = _executeScript(
        "../transactions/flowToken/scripts/get_balance.cdc",
        [account]
    ).returnValue! as! UFix64
    return balance!
}

access(all) fun getFeesBalance(): UFix64 {
    var balance = _executeScript(
        "../transactions/FlowServiceAccount/scripts/get_fees_balance.cdc",
        []
    ).returnValue! as! UFix64
    return balance!
}

access(all)
fun _executeScript(_ path: String, _ args: [AnyStruct]): Test.ScriptResult {
    return Test.executeScript(Test.readFile(path), args)
}