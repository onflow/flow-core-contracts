import "FlowTransactionScheduler"

access(all) fun main(): [UInt64] {
    return FlowTransactionScheduler.getCanceledTransactions()
}
