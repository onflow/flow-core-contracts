import "FlowFees"

access(all) fun main(payerAcct: Address, inclusionEffort: UFix64, maxExecutionEffort: UFix64): FlowFees.VerifyPayerBalanceResult {
    let authAcct = getAuthAccount<auth(BorrowValue) &Account>(payerAcct)
    return FlowFees.verifyPayersBalanceForTransactionExecution(authAcct, inclusionEffort: inclusionEffort,
        maxExecutionEffort: maxExecutionEffort)
}