import "FlowTransactionScheduler"

access(all) fun main(id: UInt64): FlowTransactionScheduler.TransactionData? {
    return FlowTransactionScheduler.getTransactionData(id: id)
}
