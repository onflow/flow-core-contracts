import "FlowCallbackScheduler"

access(all) fun main(timestamp: UFix64, priority: UInt8): UInt64 {
    let priortyEnum = FlowCallbackScheduler.Priority(rawValue: priority)!
    return FlowCallbackScheduler.getSlotAvailableEffort(timestamp: timestamp, priority: priortyEnum)
}
