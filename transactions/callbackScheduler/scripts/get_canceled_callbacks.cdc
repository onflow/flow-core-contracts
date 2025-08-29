import "FlowCallbackScheduler"

access(all) fun main(): [UInt64] {
    return FlowCallbackScheduler.getCanceledCallbacks()
}
