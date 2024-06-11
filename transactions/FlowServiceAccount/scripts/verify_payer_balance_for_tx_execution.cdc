import FlowFees from 0xFLOWFEESADDRESS

pub fun main(payerAcct: Address, inclusionEffort: UFix64, maxExecutionEffort: UFix64): FlowFees.VerifyPayerBalanceResult {
    let authAcct = getAuthAccount(payerAcct)
    return FlowFees.verifyPayersBalanceForTransactionExecution(authAcct, inclusionEffort: inclusionEffort,
        maxExecutionEffort: maxExecutionEffort)
}