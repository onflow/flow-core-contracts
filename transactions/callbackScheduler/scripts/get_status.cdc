import "FlowCallbackScheduler"

access(all) fun main(id: UInt64): UInt8 {
    let status = FlowCallbackScheduler.getStatus(id: id)
        ?? panic("Invalid ID: \(id) callback not found")
        
    return status.rawValue
}
