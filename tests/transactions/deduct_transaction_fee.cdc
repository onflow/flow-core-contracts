import FlowFees from 0x0000000000000007

/// Test-only: directly calls FlowFees.deductTransactionFee
/// the same way the FVM does after executing a transaction
transaction(inclusionEffort: UFix64, executionEffort: UFix64) {
    prepare(payer: auth(BorrowValue) &Account) {
        FlowFees.deductTransactionFee(payer, inclusionEffort: inclusionEffort, executionEffort: executionEffort)
    }
}
