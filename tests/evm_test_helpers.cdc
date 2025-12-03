import Test
import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"

// Account 7 is where new contracts are deployed by default
access(all) let adminAcct = Test.getAccount(0x0000000000000007)

access(all) let serviceAcct = Test.serviceAccount()

/** ---------------------------------------------------------------------------------
 Test helper functions
 --------------------------------------------------------------------------------- */

access(all) fun setupCOATransaction(amount: UFix64) {
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/accounts/setup_coa.cdc"),
        authorizers: [adminAcct.address],
        signers: [adminAcct],
        arguments: [amount],
    )
    var result = Test.executeTransaction(tx)

    Test.expect(result, Test.beSucceeded())
}

access(all) fun scheduleCOATransaction(
    timestamp: UFix64,
    fee: UFix64,
    effort: UInt64,
    priority: UInt8,
    coaTXTypeEnum: UInt8,
    revertOnFailure: Bool,
    amount: UFix64?,
    callToEVMAddress: String?,
    data: [UInt8]?,
    gasLimit: UInt64?,
    value: UInt?,
    testName: String,
    failWithErr: String?
) {
    var tx = Test.Transaction(
        code: Test.readFile("../transactions/transactionScheduler/schedule_coa_transaction.cdc"),
        authorizers: [adminAcct.address],
        signers: [adminAcct],
        arguments: [timestamp, fee, effort, priority, coaTXTypeEnum, revertOnFailure, amount, callToEVMAddress, data, gasLimit, value],
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

access(all) fun createCOAHandlerParams(
    coaTXTypeEnum: UInt8,
    revertOnFailure: Bool,
    amount: UFix64?,
    callToEVMAddress: String?,
    data: [UInt8]?,
    gasLimit: UInt64?,
    value: UInt?,
    testName: String,
    failWithErr: String?
) {

    let args = [coaTXTypeEnum, revertOnFailure, amount, callToEVMAddress, data, gasLimit, value]
    var result = Test.executeScript(Test.readFile("./scripts/create_coa_handler_params.cdc"), args)

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

// access(all)
// fun _executeScript(_ path: String, _ args: [AnyStruct]): Test.ScriptResult {
//     return Test.executeScript(Test.readFile(path), args)
// }