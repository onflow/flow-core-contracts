import "FlowTransactionScheduler"

access(all) fun main(startTimestamp: UFix64, endTimestamp: UFix64): {UFix64: {UInt8: [UInt64]}} {
    return FlowTransactionScheduler.getTransactionsForTimeframe(startTimestamp: startTimestamp, endTimestamp: endTimestamp)
}
