
import "FlowTransactionSchedulerUtils"

access(all) fun main(txType: UInt8,
                     revertOnFailure: Bool,
                     amount: UFix64?,
                     callToEVMAddress: String?,
                     data: [UInt8]?,
                     gasLimit: UInt64?,
                     value: UInt?): FlowTransactionSchedulerUtils.COAHandlerParams {

    let coaHandlerParams = FlowTransactionSchedulerUtils.COAHandlerParams(
            txType: txType,
            revertOnFailure: revertOnFailure,
            amount: amount,
            callToEVMAddress: callToEVMAddress,
            data: data,
            gasLimit: gasLimit,
            value: value
        )

    return coaHandlerParams
}
