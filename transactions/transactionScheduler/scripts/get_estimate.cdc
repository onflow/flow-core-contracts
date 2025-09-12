import "FlowTransactionScheduler"

access(all) fun main(
    data: AnyStruct?,
    timestamp: UFix64,
    priority: UInt8,
    executionEffort: UInt64
): FlowTransactionScheduler.EstimatedScheduledTransaction {
    var priorityEnum: FlowTransactionScheduler.Priority = FlowTransactionScheduler.Priority.High
    if priority == 0 {
        priorityEnum = FlowTransactionScheduler.Priority.High
    } else if priority == 1 {
        priorityEnum = FlowTransactionScheduler.Priority.Medium
    } else if priority == 2 {
        priorityEnum = FlowTransactionScheduler.Priority.Low
    } else {
        panic("Invalid priority: \(priority). Must be 0 (High), 1 (Medium), or 2 (Low)")
    }
    
    return FlowTransactionScheduler.estimate(
        data: data,
        timestamp: timestamp,
        priority: priorityEnum,
        executionEffort: executionEffort
    )
}
