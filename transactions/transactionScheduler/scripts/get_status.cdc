import "FlowTransactionScheduler"

access(all) fun main(id: UInt64): UInt8 {
    let status = FlowTransactionScheduler.getStatus(id: id)
        ?? panic("Invalid ID: \(id) transaction not found")
        
    return status.rawValue
}
