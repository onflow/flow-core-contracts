import "FlowCallbackScheduler"

access(all) fun main(id: UInt64): FlowCallbackScheduler.CallbackData? {
    return FlowCallbackScheduler.getCallbackData(id: id)
}
