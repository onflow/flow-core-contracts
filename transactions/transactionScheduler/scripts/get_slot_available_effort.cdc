import "FlowTransactionScheduler"

access(all) fun main(timestamp: UFix64, priority: UInt8): UInt64 {
    let priortyEnum = FlowTransactionScheduler.Priority(rawValue: priority)!
    return FlowTransactionScheduler.getSlotAvailableEffort(timestamp: timestamp, priority: priortyEnum)
}
