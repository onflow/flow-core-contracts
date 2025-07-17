import "FlowCallbackScheduler"

access(all) fun main(id: UInt64): UInt8 {
    return FlowCallbackScheduler.getStatus(id: id)!.rawValue
}
